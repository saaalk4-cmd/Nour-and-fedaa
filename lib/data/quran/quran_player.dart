import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// يتلو قائمة آيات بالترتيب، مع تكرار كل آية [repeatEach] مرة (للحفظ).
abstract class QuranPlayer {
  Future<void> playAll(
    List<String> urls, {
    int repeatEach = 1,
    void Function(int index)? onAyah,
  });
  Future<void> stop();
}

class AudioQuranPlayer implements QuranPlayer {
  AudioPlayer? _player;
  bool _stopped = false;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  Future<void> playAll(
    List<String> urls, {
    int repeatEach = 1,
    void Function(int index)? onAyah,
  }) async {
    _stopped = false;
    for (var i = 0; i < urls.length; i++) {
      for (var r = 0; r < repeatEach; r++) {
        if (_stopped) return;
        onAyah?.call(i);
        try {
          final done = _p.onPlayerComplete.first;
          await _p.play(UrlSource(urls[i]));
          await done;
        } catch (e) {
          debugPrint('ayah audio failed: $e');
          return;
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await _player?.stop();
  }
}
