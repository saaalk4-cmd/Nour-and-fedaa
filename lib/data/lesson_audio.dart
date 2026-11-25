import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lesson.dart';

/// تشغيل صوت الدرس؛ يكتمل الـFuture عند انتهاء الصوت.
abstract class LessonAudio {
  Future<void> play(Lesson lesson);
  Future<void> stop();
}

/// إن كان للدرس ملف صوت يُشغَّل من assets، وإلا يُحاكى بانتظار قصير (لا صوت مرخّص بعد).
class AssetLessonAudio implements LessonAudio {
  AssetLessonAudio({
    AudioPlayer? player,
    this.fallbackDuration = const Duration(seconds: 2),
  }) : _player = player;

  AudioPlayer? _player;
  final Duration fallbackDuration;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  Future<void> play(Lesson lesson) async {
    final path = lesson.audio;
    if (path == null) {
      await Future<void>.delayed(fallbackDuration);
      return;
    }
    try {
      // AssetSource يتوقع المسار بلا بادئة assets/
      final rel = path.startsWith('assets/') ? path.substring(7) : path;
      await _p.stop();
      final done = _p.onPlayerComplete.first;
      await _p.play(AssetSource(rel));
      await done;
    } catch (e) {
      // لا نترك الطفل عالقًا إن تعذّر الصوت.
      debugPrint('lesson audio failed: $e');
    }
  }

  @override
  Future<void> stop() async => _player?.stop();
}

final lessonAudioProvider = Provider<LessonAudio>((ref) {
  final audio = AssetLessonAudio();
  ref.onDispose(() => audio.stop());
  return audio;
});
