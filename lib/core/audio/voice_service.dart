import 'dart:convert';

import 'package:crypto/crypto.dart';

/// إعدادات الصوت التي يضبطها ولي الأمر (تُحفظ في قاعدة البيانات).
class VoiceSettings {
  const VoiceSettings({
    this.pauseMs = 1000,
    this.rate = 0.45,
    this.voiceVolume = 1.0,
    this.effectsVolume = 1.0,
    this.autoRead = true,
  });

  /// الوقفة بعد كل جملة قبل التي بعدها (تدع الجملة تُفهم ولا تتداخل).
  final int pauseMs;

  /// سرعة الكلام الآلي (0.3 بطيء جدًا … 0.6 سريع).
  final double rate;
  final double voiceVolume;
  final double effectsVolume;

  /// قراءة الدرس تلقائيًا عند فتحه (وإلا عند ضغط 🔊 فقط).
  final bool autoRead;

  static const slow = 0.35;
  static const normal = 0.45;
  static const fast = 0.6;

  VoiceSettings copyWith({int? pauseMs, double? rate, double? voiceVolume, double? effectsVolume, bool? autoRead}) =>
      VoiceSettings(
        pauseMs: pauseMs ?? this.pauseMs,
        rate: rate ?? this.rate,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        effectsVolume: effectsVolume ?? this.effectsVolume,
        autoRead: autoRead ?? this.autoRead,
      );
}

/// محرك يقبل ضبط السرعة والعلو (flutter_tts). المحركات البسيطة في الاختبارات لا تحتاجه.
abstract interface class TuneableSpeech {
  Future<void> tune({required double rate, required double volume});
}

/// تسجيلات صوت الأهل (يُبحث فيها أولًا): مفتاح النص ← ملف على الجهاز.
abstract class UserVoice {
  Future<bool> has(String key);
  Future<void> playAndWait(String key);
  Future<void> stop();
}

/// محرّك النطق (يُستبدل في الاختبارات). التنفيذ الحقيقي: flutter_tts.
abstract class SpeechEngine {
  Future<void> speak(String text);

  /// ينطق ويرجع بعد انتهاء الجملة (أو إيقافها).
  Future<void> speakAndWait(String text);
  Future<void> stop();
}

/// مقاطع صوتية مسجّلة مسبقًا بصوت عالي الجودة (تُولَّد وقت البناء في CI).
/// المفتاح = [VoiceService.clipKey] للنص بعد [VoiceService.clean].
abstract class ClipPlayer {
  Future<bool> has(String key);
  Future<void> play(String key);

  /// يشغّل ويرجع بعد انتهاء المقطع (أو إيقافه).
  Future<void> playAndWait(String key);
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
    ClipPlayer? clips,
    UserVoice? userVoice,
    Future<VoiceSettings> Function()? readSettings,
  })  : _engine = engine,
        _clips = clips,
        _user = userVoice,
        _readSettings = readSettings,
        _readEnabled = readEnabled,
        _writeEnabled = writeEnabled;

  final SpeechEngine _engine;
  final ClipPlayer? _clips;
  final UserVoice? _user;
  final Future<VoiceSettings> Function()? _readSettings;
  VoiceSettings? _settings;

  /// يتغير عند كل إيقاف: يلغي الانتظار والوقفات الجارية فورًا.
  int _gen = 0;
  final Future<bool> Function() _readEnabled;
  final Future<void> Function(bool enabled) _writeEnabled;
  bool? _enabled;

  Future<bool> isEnabled() async => _enabled ??= await _readEnabled();

  Future<VoiceSettings> settings() async {
    final cached = _settings;
    if (cached != null) return cached;
    try {
      final read = _readSettings;
      final s = read == null ? const VoiceSettings() : await read();
      return _settings = s;
    } catch (_) {
      return const VoiceSettings();
    }
  }

  /// بعد أن يغيّر ولي الأمر شيئًا في الإعدادات.
  void refreshSettings() => _settings = null;

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

  /// مفتاح المقطع المسجّل لنص منظَّف (أول 16 حرفًا من sha1). يطابق tools/build_voice.py.
  static String clipKey(String cleaned) => sha1.convert(utf8.encode(cleaned)).toString().substring(0, 16);

  /// يُشغّل صوت الأهل المسجّل إن وُجد، وإلا المقطع المسجّل مسبقًا، وإلا صوت الجهاز.
  Future<void> speak(String text) => _say(text, wait: false);

  /// يقول الجملة وينتظر حتى تنتهي (بحد أقصى [max] حتى لا تنتظر الطفلة للأبد لو تعطّل الصوت)،
  /// ثم يترك وقفة قصيرة (إعداد ولي الأمر) قبل أي جملة بعدها. أي إيقاف يقطع الانتظار فورًا.
  Future<void> sayAndWait(String text, {Duration max = const Duration(seconds: 5), bool pause = true}) async {
    try {
      final spoke = await _say(text, wait: true).timeout(max, onTimeout: () => false);
      if (spoke && pause) await _pause();
    } catch (_) {
      // انتهى الوقت أو تعطّل الصوت: نكمل.
    }
  }

  /// وقفة بين جملتين، تنتهي مبكرًا لو بدأ كلام جديد أو أُوقف الصوت.
  Future<void> _pause() async {
    final gen = _gen;
    final ms = (await settings()).pauseMs;
    var left = ms;
    while (left > 0 && gen == _gen) {
      final step = left < 50 ? left : 50;
      await Future<void>.delayed(Duration(milliseconds: step));
      left -= step;
    }
  }

  /// وقفة صريحة (مثلًا بين سطرين من الشرح) تحترم إعداد ولي الأمر.
  Future<void> pause() => _pause();

  /// يشغّل تسجيل الأهل لهذا النص إن وُجد (للأحاديث: لا يُنطق نص الحديث آليًا أبدًا).
  /// يرجع true لو وُجد التسجيل وانتهى تشغيله.
  Future<bool> playRecorded(String text) async {
    try {
      if (!await isEnabled()) return false;
      final user = _user;
      final t = clean(text);
      if (user == null || t.isEmpty) return false;
      final key = clipKey(t);
      if (!await user.has(key)) return false;
      await stop();
      await user.playAndWait(key);
      await _pause();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// هل لدى الأهل تسجيل لهذا النص؟
  Future<bool> hasRecorded(String text) async {
    try {
      final user = _user;
      final t = clean(text);
      return user != null && t.isNotEmpty && await user.has(clipKey(t));
    } catch (_) {
      return false;
    }
  }

  /// true لو نُطقت الجملة فعلًا (ولم تُكتم أو تُلغَ).
  Future<bool> _say(String text, {required bool wait}) async {
    try {
      if (!await isEnabled()) return false;
      final t = clean(text);
      if (t.isEmpty) return false;
      await stop();
      final gen = _gen;
      final key = clipKey(t);
      final user = _user;
      if (user != null && await user.has(key)) {
        await user.playAndWait(key);
        return gen == _gen;
      }
      final clips = _clips;
      if (clips != null && await clips.has(key)) {
        await (wait ? clips.playAndWait(key) : clips.play(key));
        return gen == _gen;
      }
      final engine = _engine;
      if (engine is TuneableSpeech) {
        final s = await settings();
        await (engine as TuneableSpeech).tune(rate: s.rate, volume: s.voiceVolume);
      }
      await (wait ? engine.speakAndWait(t) : engine.speak(t));
      return gen == _gen;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _gen++;
    try {
      await _user?.stop();
    } catch (_) {}
    try {
      await _clips?.stop();
    } catch (_) {}
    try {
      await _engine.stop();
    } catch (_) {}
  }
}
