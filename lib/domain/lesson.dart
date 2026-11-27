import 'dart:convert';

import 'age_band.dart';

enum StepType { listen, repeat, choose, surah, hadith, reward }

/// خطوة في الدرس: استماع، ترديد، اختيار، أو مكافأة.
class LessonStep {
  const LessonStep(
    this.type, {
    this.times = 0,
    this.stars = 0,
    this.prompt,
    this.question,
    this.options = const [],
    this.optionLabels = const [],
    this.answer = 0,
    this.surah = 0,
    this.repeatEach = 1,
    this.hadith,
  });

  final StepType type;

  /// عدد مرات الترديد (لخطوة repeat).
  final int times;

  /// عدد النجوم الممنوحة (لخطوة reward).
  final int stars;

  /// خطوة choose: رمز كبير يُعرض (حرف أو إيموجي)، والسؤال، والخيارات،
  /// وتسميات اختيارية تحت كل خيار، وفهرس الإجابة الصحيحة.
  final String? prompt;
  final String? question;
  final List<String> options;
  final List<String> optionLabels;
  final int answer;

  /// خطوة surah: رقم السورة، وعدد مرات تكرار كل آية (١ استماع، ٣ حفظ).
  final int surah;
  final int repeatEach;

  /// خطوة hadith: معرّف الحديث في assets/content/hadith.
  final String? hadith;

  factory LessonStep.fromJson(Map<String, dynamic> j) {
    final type = StepType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => throw FormatException('نوع خطوة غير معروف: ${j['type']}'),
    );
    final options = ((j['options'] as List<dynamic>?) ?? const []).cast<String>();
    final labels =
        ((j['option_labels'] as List<dynamic>?) ?? const []).cast<String>();
    final answer = (j['answer'] as int?) ?? 0;
    if (type == StepType.choose) {
      if (j['question'] == null || options.length < 2) {
        throw const FormatException('خطوة اختيار بلا سؤال أو خيارات كافية');
      }
      if (answer < 0 || answer >= options.length) {
        throw const FormatException('فهرس الإجابة خارج الخيارات');
      }
      if (labels.isNotEmpty && labels.length != options.length) {
        throw const FormatException('عدد التسميات لا يطابق الخيارات');
      }
    }
    final surah = (j['surah'] as int?) ?? 0;
    if (type == StepType.surah && (surah < 1 || surah > 114)) {
      throw const FormatException('رقم السورة غير صالح');
    }
    if (type == StepType.hadith && j['hadith'] is! String) {
      throw const FormatException('خطوة حديث بلا معرّف');
    }
    return LessonStep(
      type,
      times: (j['times'] as int?) ?? 0,
      stars: (j['stars'] as int?) ?? 0,
      prompt: j['prompt'] as String?,
      question: j['question'] as String?,
      options: options,
      optionLabels: labels,
      answer: answer,
      surah: surah,
      repeatEach: (j['repeat_each'] as int?) ?? 1,
      hadith: j['hadith'] as String?,
    );
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.band,
    required this.sourceType,
    required this.steps,
    this.subtitle,
    this.section,
    this.icon,
    this.audio,
    this.audioLicense,
    this.level = 1,
    this.sourceNote,
    this.contentVerified = false,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// القسم/البلاطة التي يظهر فيها الدرس (مثل t_adab).
  final String? section;

  /// أيقونة الدرس (إيموجي) تُعرض للبراعم بدل العنوان المكتوب.
  final String? icon;

  /// مسار ملف الصوت في assets (null = لم يُسجَّل بعد).
  final String? audio;

  /// مصدر ترخيص الصوت؛ إلزامي متى وُجد [audio].
  final String? audioLicense;

  bool get hasAudio => audio != null;

  /// مستوى الدرس داخل مساره (١–٣)، يُقارن بنتيجة اختبار المستوى.
  final int level;

  /// مسار اختبار المستوى الذي يتبعه قسم الدرس (null = قسم بلا اختبار).
  String? get placementTrack => switch (section) {
        'arabic' => 'arabic',
        'prayer' => 'salah',
        'aqeedah' => 'maa_la_yasa',
        'quran' => 'quran',
        _ => null,
      };

  /// البراعم لا يقرؤون: لا نعرض لهم عنوانًا مكتوبًا (العنوان للأهل).
  bool get textFreeForChild => band == AgeBand.buraem;
  final AgeBand band;

  /// quran | sahih_sunnah | seerah | scholars | educational
  final String sourceType;
  final String? sourceNote;
  final bool contentVerified;
  final List<LessonStep> steps;

  static const sourceTypes = {
    'quran',
    'sahih_sunnah',
    'seerah',
    'scholars',
    'educational',
  };

  /// النجوم التي يمنحها الدرس عند إتمامه (من خطوة المكافأة).
  int get rewardStars => steps
      .where((s) => s.type == StepType.reward)
      .fold(0, (sum, s) => sum + s.stars);

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final band = AgeBand.byName(j['band'] as String?);
    if (band == null) throw FormatException('فئة غير معروفة: ${j['band']}');
    final source = j['source_type'] as String?;
    if (source == null || !sourceTypes.contains(source)) {
      throw FormatException('source_type مفقود أو غير صالح: $source');
    }
    final steps = (j['steps'] as List<dynamic>? ?? const [])
        .map((e) => LessonStep.fromJson(e as Map<String, dynamic>))
        .toList();
    if (steps.isEmpty) throw const FormatException('الدرس بلا خطوات');
    final audio = j['audio'] as String?;
    final license = j['audio_license'] as String?;
    if (audio != null && (license == null || license.trim().isEmpty)) {
      throw const FormatException('الصوت بلا audio_license (الترخيص إلزامي)');
    }
    return Lesson(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String?,
      section: j['section'] as String?,
      icon: j['icon'] as String?,
      audio: audio,
      audioLicense: license,
      level: _level(j['level']),
      band: band,
      sourceType: source,
      sourceNote: j['source_note'] as String?,
      contentVerified: (j['content_verified'] as bool?) ?? false,
      steps: steps,
    );
  }

  factory Lesson.fromJsonString(String s) =>
      Lesson.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

int _level(Object? v) {
  final l = (v as int?) ?? 1;
  if (l < 1 || l > 3) throw FormatException('مستوى الدرس خارج ١–٣: $l');
  return l;
}
