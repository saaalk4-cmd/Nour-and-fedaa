import 'package:audioplayers/audioplayers.dart';

import '../../data/repositories/settings_repository.dart';
import 'intro_audio.dart';

/// موسيقى المقدمة الاحتياطية من الأصل المحلي (assets/audio/intro_score.wav، يولّدها
/// tools/generate_intro_score.py). تحترم مفتاح الصوت في لوحة الأهل ولا ترمي أخطاء أبدًا.
class AssetIntroAudio extends IntroAudio {
  AssetIntroAudio();

  AudioPlayer? _player;

  @override
  Future<void> start() async {
    try {
      if (!await SettingsRepository().soundEnabled()) return;
      final p = AudioPlayer();
      _player = p;
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.8);
      await p.play(AssetSource('audio/intro_score.wav'));
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    try {
      await _player?.resume();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    final p = _player;
    _player = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }
}
