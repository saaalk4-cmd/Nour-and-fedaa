import 'package:flutter_riverpod/flutter_riverpod.dart';

/// تشغيل صوت الدرس. التنفيذ الفعلي يأتي بعد حسم ترخيص التلاوات.
abstract class LessonAudio {
  Future<void> play(String lessonId);
}

/// تنفيذ مؤقت: ينتظر مدة قصيرة بدل تشغيل صوت (لا يوجد صوت مرخّص بعد).
class SimulatedLessonAudio implements LessonAudio {
  const SimulatedLessonAudio({this.duration = const Duration(seconds: 2)});

  final Duration duration;

  @override
  Future<void> play(String lessonId) => Future.delayed(duration);
}

final lessonAudioProvider =
    Provider<LessonAudio>((_) => const SimulatedLessonAudio());
