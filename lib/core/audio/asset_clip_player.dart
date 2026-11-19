import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'voice_service.dart';

/// يشغّل المقاطع المسجّلة من assets/audio/voice/<key>.mp3.
/// الفهرس index.json يُولَّد في CI؛ لو غير موجود يعمل التطبيق بصوت الجهاز فقط.
class AssetClipPlayer implements ClipPlayer {
  static const String indexAsset = 'assets/audio/voice/index.json';

  Future<Set<String>>? _keys;
  AudioPlayer? _player;

  Future<Set<String>> _load() async {
    try {
      final raw = await rootBundle.loadString(indexAsset);
      final list = (jsonDecode(raw) as Map<String, dynamic>)['clips'] as List<dynamic>;
      return {for (final k in list) k as String};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<bool> has(String key) async => (await (_keys ??= _load())).contains(key);

  @override
  Future<void> play(String key) async {
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    await p.play(AssetSource('audio/voice/$key.mp3'));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }
}
