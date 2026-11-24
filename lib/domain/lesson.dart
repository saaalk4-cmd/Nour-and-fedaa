import 'dart:convert';

import 'age_band.dart';

enum StepType { listen, repeat, reward }

/// خطوة في الدرس: استماع، ثم ترديد، ثم مكافأة.
class LessonStep {
  const LessonStep(this.type, {this.times = 0, this.stars = 0});

  final StepType type;

  /// عدد مرات الترديد (لخطوة repeat).
  final int times;

  /// عدد النجوم الممنوحة (لخطوة reward).
  final int stars;

  factory LessonStep.fromJson(Map<String, dynamic> j) {
    final type = StepType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => throw FormatException('نوع خطوة غير معروف: ${j['type']}'),
    );
    return LessonStep(
      type,
      times: (j['times'] as int?) ?? 0,
      stars: (j['stars'] as int?) ?? 0,
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
    this.sourceNote,
    this.contentVerified = false,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// القسم/البلاطة التي يظهر فيها الدرس (مثل t_adab).
  final String? section;
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
    return Lesson(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String?,
      section: j['section'] as String?,
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
