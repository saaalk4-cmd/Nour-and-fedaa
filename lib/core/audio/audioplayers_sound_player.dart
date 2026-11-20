import 'package:audioplayers/audioplayers.dart';

import 'sound_service.dart';

/// تنفيذ المشغّل باستخدام حزمة audioplayers (يعمل بدون إنترنت من assets).
class AudioplayersSoundPlayer implements SoundPlayer, VolumeAware {
  @override
  double volume = 1.0;

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Future<void> play(SoundEffect effect) async {
    await _player.stop();
    await _player.play(AssetSource(effect.asset), volume: volume);
  }
}
