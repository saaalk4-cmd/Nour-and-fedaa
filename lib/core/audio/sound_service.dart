/// المؤثرات الصوتية المتاحة. الملفات في assets/audio (راجع tools/generate_sounds.py).
enum SoundEffect {
  tap('audio/tap.wav'),
  correct('audio/correct.wav'),
  success('audio/success.wav'),
  levelUp('audio/levelup.wav');

  const SoundEffect(this.asset);

  /// مسار الملف داخل assets (بدون البادئة assets/).
  final String asset;
}

/// واجهة المشغّل: تسمح باستبدال التنفيذ (وبالاختبار بدون plugin).
abstract class SoundPlayer {
  Future<void> play(SoundEffect effect);
}

/// يقرر هل يُشغَّل الصوت (إعداد ولي الأمر) ويُمرّره للمشغّل.
/// لا يرمي استثناءات أبدًا: الصوت ميزة إضافية ولا يجب أن يكسر التطبيق.
class SoundService {
  SoundService({
    required SoundPlayer player,
    required Future<bool> Function() readEnabled,
    required Future<void> Function(bool enabled) writeEnabled,
  })  : _player = player,
        _readEnabled = readEnabled,
        _writeEnabled = writeEnabled;

  final SoundPlayer _player;
  final Future<bool> Function() _readEnabled;
  final Future<void> Function(bool enabled) _writeEnabled;

  bool? _enabled;

  Future<bool> isEnabled() async => _enabled ??= await _readEnabled();

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _writeEnabled(value);
  }

  Future<void> play(SoundEffect effect) async {
    try {
      if (!await isEnabled()) return;
      await _player.play(effect);
    } catch (_) {
      // نتجاهل أي خطأ صوتي.
    }
  }
}
