import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../packs/content_packs.dart';
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
  AssetClipPlayer({this.packs});

  /// حزمة الأصوات المنزّلة (جمل الدروس الطويلة): يُبحث فيها لو المقطع ليس داخل التطبيق.
  final PackStore? packs;

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

  Future<bool> _bundled(String key) async => (await (_keys ??= _load())).contains(key);

  /// المصدر: داخل التطبيق، وإلا من حزمة الأصوات المنزّلة.
  Future<Source?> _source(String key) async {
    if (await _bundled(key)) return AssetSource('audio/voice/$key.mp3');
    final path = await packs?.voicePath(key);
    return path == null ? null : DeviceFileSource(path);
  }

  @override
  Future<bool> has(String key) async => await _source(key) != null;

  @override
  Future<void> play(String key) async {
    final src = await _source(key);
    if (src == null) return;
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    await p.play(src);
  }

  @override
  Future<void> playAndWait(String key) async {
    final src = await _source(key);
    if (src == null) return;
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    // ينتهي عند اكتمال المقطع أو عند إيقافه (ضغطة أخرى، أو الخروج).
    await p.play(src);
    await waitUntilFinished(p);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }
}
