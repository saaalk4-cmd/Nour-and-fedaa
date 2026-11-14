/// محرّك النطق (يُستبدل في الاختبارات). التنفيذ الحقيقي: flutter_tts.
abstract class SpeechEngine {
  Future<void> speak(String text);
  Future<void> stop();
}

/// قراءة الكلام بصوت عالٍ لطفلة لا تقرأ بعد (ولا يوجد والد بجانبها).
///
/// قواعد صارمة:
/// - لا يُستخدم لقراءة القرآن أو الحديث (النطق الآلي لا يضمن التجويد/الضبط)؛
///   المحتوى الديني يُسمَع بتلاوة مسجّلة أو لا يُنطق (يقرر ذلك الاستدعاء).
/// - لا يرمي استثناءات أبدًا: الصوت ميزة مساعدة ولا يجب أن يكسر التطبيق.
class VoiceService {
  VoiceService({
    required SpeechEngine engine,
    required Future<bool> Function() readEnabled,
    required Future<void> Function(bool enabled) writeEnabled,
  })  : _engine = engine,
        _readEnabled = readEnabled,
        _writeEnabled = writeEnabled;

  final SpeechEngine _engine;
  final Future<bool> Function() _readEnabled;
  final Future<void> Function(bool enabled) _writeEnabled;
  bool? _enabled;

  Future<bool> isEnabled() async => _enabled ??= await _readEnabled();

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _writeEnabled(value);
    if (!value) await stop();
  }

  static final RegExp _symbols = RegExp(
    '[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]',
    unicode: true,
  );

  /// يزيل الرموز التعبيرية (يقرؤها المحرّك بأسماء غريبة) ويوحّد الفراغات.
  static String clean(String raw) => raw
      .replaceAll(_symbols, ' ')
      .replaceAll(RegExp(r'\s*\n\s*'), '. ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> speak(String text) async {
    try {
      if (!await isEnabled()) return;
      final t = clean(text);
      if (t.isEmpty) return;
      await _engine.stop();
      await _engine.speak(t);
    } catch (_) {
      // نتجاهل أي خطأ في النطق.
    }
  }

  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {}
  }
}
