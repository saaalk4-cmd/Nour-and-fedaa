import 'cinema_painter.dart';

/// طبقة الصوت المستقلة للمقدمة (موسيقى ومؤثرات). تعمل مع الفيلم الحقيقي والمقدمة الاحتياطية
/// بنفس لحظات [kCinemaCues]، فإضافة الصوت لاحقًا لا تمسّ التنقّل ولا الشاشات.
///
/// لإضافة صوت: ضع الملف في assets/audio/ وسجّله هنا في [kIntroCueSounds]
/// ثم اربط [IntroAudio.onCue] بـ SoundService. الفيلم (إن احتوى صوتًا) يشغّل صوته بنفسه.
const Map<String, String> kIntroCueSounds = <String, String>{};

class IntroAudio {
  const IntroAudio();

  /// الملف المرتبط بلحظة [cue] أو null إن لم يُضف صوت لها بعد.
  String? soundFor(String cue) => kIntroCueSounds[cue];

  /// يُستدعى عند كل لحظة؛ الافتراضي: لا شيء (آمن).
  void onCue(String cue) {}
}

/// اللحظة المقابلة لموضع [positionSeconds] من فيلم مدته [durationSeconds]
/// (تُقاس نسبيًا على جدول 45 ثانية الأصلي).
double cueTimeFor(double positionSeconds, double durationSeconds) =>
    durationSeconds <= 0 ? 0 : positionSeconds / durationSeconds * kCinemaSeconds;
