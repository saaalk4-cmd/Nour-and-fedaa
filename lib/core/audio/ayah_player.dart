import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

/// تشغيل تلاوة آية مسجّلة من assets/audio/quran/<سورة>_<آية>.mp3.
/// الملفات تُنزَّل أثناء البناء (tools/fetch_quran_audio.py)؛ إن لم توجد يرجع false.
class AyahPlayer {
  AudioPlayer? _player;

  static String assetPath(int surah, int ayah) => 'audio/quran/${surah}_$ayah.mp3';

  Future<bool> play(int surah, int ayah) async {
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

  Future<void> stop() async {
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
