import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'voice_service.dart';

/// ينتظر حتى ينتهي المقطع الذي بدأ للتو، أو يُوقَف بعد أن بدأ فعلًا.
/// (حالة «متوقف» القديمة قبل البدء لا تُحسب، وإلا تُفتح الشاشة التالية فورًا وتنقطع الجملة.)
Future<void> waitUntilFinished(AudioPlayer p) async {
  var started = p.state == PlayerState.playing;
  await for (final s in p.onPlayerStateChanged) {
    if (s == PlayerState.playing) {
      started = true;
    } else if (s == PlayerState.completed || s == PlayerState.disposed) {
      return;
    } else if (started && (s == PlayerState.stopped || s == PlayerState.paused)) {
      return;
    }
  }
}

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
  Future<void> playAndWait(String key) async {
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    // ينتهي عند اكتمال المقطع أو عند إيقافه (ضغطة أخرى، أو الخروج).
    await p.play(AssetSource('audio/voice/$key.mp3'));
    await waitUntilFinished(p);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }
}
