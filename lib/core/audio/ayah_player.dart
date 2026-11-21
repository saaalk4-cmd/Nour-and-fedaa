import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'asset_clip_player.dart' show waitUntilFinished;

/// تشغيل تلاوة آية مسجّلة من assets/audio/quran/<سورة>_<آية>.mp3.
/// الملفات تُنزَّل أثناء البناء (tools/fetch_quran_audio.py)؛ إن لم توجد يرجع false.
class AyahPlayer {
  AyahPlayer({this.packFile});

  /// تلاوة آيات الأجزاء من الحزم المنزّلة (أو null). يُبحث فيها أولًا.
  final Future<String?> Function(int surah, int ayah)? packFile;

  AudioPlayer? _player;

  static String assetPath(int surah, int ayah) => 'audio/quran/${surah}_$ayah.mp3';

  /// مصدر الآية: الحزمة المنزّلة، وإلا داخل التطبيق، وإلا null.
  Future<Source?> source(int surah, int ayah) async {
    try {
      final f = await packFile?.call(surah, ayah);
      if (f != null) return DeviceFileSource(f);
    } catch (_) {}
    try {
      await rootBundle.load('assets/${assetPath(surah, ayah)}');
      return AssetSource(assetPath(surah, ayah));
    } catch (_) {
      return null;
    }
  }

  Future<bool> play(int surah, int ayah) async {
    _run++;
    final src = await source(surah, ayah);
    if (src == null) return false; // لا توجد تلاوة في هذه النسخة
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(src);
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
      final src = await source(surah, a);
      if (src == null) return a > from;
      try {
        final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        await p.stop();
        await p.play(src);
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
