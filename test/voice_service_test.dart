import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/flutter_tts_engine.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';

class _FakeEngine implements SpeechEngine {
  final List<String> spoken = [];
  bool throwOnSpeak = false;

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw StateError('tts failure');
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

VoiceService _service(_FakeEngine e, {bool enabled = true}) {
  var value = enabled;
  return VoiceService(
    engine: e,
    readEnabled: () async => value,
    writeEnabled: (v) async => value = v,
  );
}

void main() {
  test('clean removes emoji and flattens lines', () {
    expect(VoiceService.clean('كم نجمة؟ ⭐⭐'), 'كم نجمة؟');
    expect(VoiceService.clean('أين الشمس؟\n☀️ 🌙'), 'أين الشمس؟.');
    expect(VoiceService.clean('🎉'), isEmpty);
  });

  test('speaks cleaned text when enabled', () async {
    final e = _FakeEngine();
    await _service(e).speak('مرحبًا يا نور 🌟');
    expect(e.spoken, ['مرحبًا يا نور']);
  });

  test('stays silent when the parent turned the voice off', () async {
    final e = _FakeEngine();
    final s = _service(e, enabled: false);
    await s.speak('مرحبًا');
    expect(e.spoken, isEmpty);
  });

  test('turning it off stops speech and persists', () async {
    final e = _FakeEngine();
    final s = _service(e);
    await s.setEnabled(false);
    await s.speak('مرحبًا');
    expect(e.spoken, isEmpty);
    expect(await s.isEnabled(), isFalse);
  });

  test('a failing engine never throws', () async {
    final e = _FakeEngine()..throwOnSpeak = true;
    await _service(e).speak('مرحبًا');
  });

  test('clip key matches tools/build_voice.py (sha1, 16 chars)', () {
    expect(VoiceService.clipKey('أحسنتِ يا فداء!'), 'cd2cf354b3645695');
  });

  test('plays the recorded clip when one exists, else the device voice', () async {
    final e = _FakeEngine();
    final clips = _FakeClips({VoiceService.clipKey('أحسنتِ يا فداء!')});
    final v = VoiceService(engine: e, readEnabled: () async => true, writeEnabled: (_) async {}, clips: clips);
    await v.speak('أحسنتِ يا فداء! 🌟');
    expect(clips.played, [VoiceService.clipKey('أحسنتِ يا فداء!')]);
    expect(e.spoken, isEmpty);
    await v.speak('جملة جديدة');
    expect(e.spoken, ['جملة جديدة']);
  });

  test('recorded clips also respect the parent voice switch', () async {
    final clips = _FakeClips({VoiceService.clipKey('نور')});
    final v = VoiceService(engine: _FakeEngine(), readEnabled: () async => false, writeEnabled: (_) async {}, clips: clips);
    await v.speak('نور');
    expect(clips.played, isEmpty);
  });

  group('device voice choice', () {
    const voices = [
      TtsVoice(name: 'en-us-x', locale: 'en-US', quality: 500),
      TtsVoice(name: 'ar-net', locale: 'ar', quality: 500, needsNetwork: true),
      TtsVoice(name: 'ar-low', locale: 'ar-EG', quality: 300),
      TtsVoice(name: 'ar-high', locale: 'ar-XA', quality: 400),
    ];

    test('picks the clearest offline Arabic voice', () {
      expect(TtsVoice.pick(voices)!.name, 'ar-high');
    });

    test('honours the voice the parent chose', () {
      expect(TtsVoice.pick(voices, preferred: 'ar-low')!.name, 'ar-low');
      expect(TtsVoice.pick(voices, preferred: 'gone')!.name, 'ar-high');
    });

    test('no Arabic voice means none', () {
      expect(TtsVoice.pick(const [TtsVoice(name: 'en', locale: 'en-US')]), isNull);
    });

    test('reads flutter_tts maps with string values', () {
      final v = TtsVoice.fromMap({'name': 'ar-xa-x-arz-local', 'locale': 'ar', 'quality': '400', 'network_required': '0'})!;
      expect(v.quality, 400);
      expect(v.needsNetwork, isFalse);
      expect(TtsVoice.fromMap({'name': 'x'}), isNull);
    });
  });
}

class _FakeClips implements ClipPlayer {
  _FakeClips(this.keys);

  final Set<String> keys;
  final List<String> played = [];

  @override
  Future<bool> has(String key) async => keys.contains(key);

  @override
  Future<void> play(String key) async => played.add(key);

  @override
  Future<void> stop() async {}
}
