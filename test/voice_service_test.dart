import 'package:flutter_test/flutter_test.dart';
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
}
