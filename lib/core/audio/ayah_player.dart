import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'asset_clip_player.dart' show waitUntilFinished;

/// تشغيل تلاوة آية مسجّلة من assets/audio/quran/<سورة>_<آية>.mp3.
/// الملفات تُنزَّل أثناء البناء (tools/fetch_quran_audio.py)؛ إن لم توجد يرجع false.
class AyahPlayer {
  AudioPlayer? _player;

  static String assetPath(int surah, int ayah) => 'audio/quran/${surah}_$ayah.mp3';

  Future<bool> play(int surah, int ayah) async {
    _run++;
    try {
      await rootBundle.load('assets/${assetPath(surah, ayah)}');
    } catch (_) {
      return false; // لا توجد تلاوة في هذه النسخة
    }
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource(assetPath(surah, ayah)));
      return true;
    } catch (_) {
      return false;
    }
  }

  int _run = 0;

  /// يتلو آية واحدة أو عدة آيات متتالية [from]..[to] وينتظر انتهاءها.
  /// يتوقف لو أُوقف التشغيل أو بدأت تلاوة أخرى. يرجع false لو لا توجد تلاوة.
  Future<bool> playRange(int surah, int from, int to) async {
    final run = ++_run;
    for (var a = from; a <= to; a++) {
      if (run != _run) return true;
      try {
        await rootBundle.load('assets/${assetPath(surah, a)}');
      } catch (_) {
        return a > from;
      }
      try {
        final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        await p.stop();
        await p.play(AssetSource(assetPath(surah, a)));
        await waitUntilFinished(p).timeout(const Duration(seconds: 90));
      } catch (_) {
        return a > from;
      }
    }
    return true;
  }

  Future<void> stop() async {
    _run++;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
