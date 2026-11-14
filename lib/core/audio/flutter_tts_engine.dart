import 'package:flutter_tts/flutter_tts.dart';

import 'voice_service.dart';

/// تنفيذ النطق بصوت النظام العربي (بطيء ولطيف للأطفال). يعمل بلا إنترنت
/// إذا كان صوت عربي منزَّلًا على الجهاز.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTts? _tts;
  Future<void>? _init;

  Future<FlutterTts> _ready() async {
    final tts = _tts ??= FlutterTts();
    _init ??= () async {
      await tts.setLanguage('ar');
      await tts.setSpeechRate(0.4);
      await tts.setPitch(1.05);
      await tts.setVolume(1.0);
    }();
    await _init;
    return tts;
  }

  @override
  Future<void> speak(String text) async => (await _ready()).speak(text);

  @override
  Future<void> stop() async => (await _ready()).stop();
}
