/// المؤثرات الصوتية المتاحة. الملفات في assets/audio (راجع tools/generate_sounds.py).
enum SoundEffect {
  tap('audio/tap.wav'),
  correct('audio/correct.wav'),
  success('audio/success.wav'),
  levelUp('audio/levelup.wav'),

  /// نغمة فرح صاعدة مع تصفيق خفيف (ثلاث إجابات ورا بعض، إنهاء المستوى).
  joy('audio/joy.wav');

  const SoundEffect(this.asset);

  /// مسار الملف داخل assets (بدون البادئة assets/).
  final String asset;
}

/// واجهة المشغّل: تسمح باستبدال التنفيذ (وبالاختبار بدون plugin).
abstract class SoundPlayer {
  Future<void> play(SoundEffect effect);
}

/// مشغّل يقبل علو المؤثرات (إعداد ولي الأمر).
abstract interface class VolumeAware {
  set volume(double v);
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

  /// علو المؤثرات (0..1) من إعدادات الأهل.
  double effectsVolume = 1.0;

  Future<void> play(SoundEffect effect) async {
    try {
      if (!await isEnabled()) return;
      final p = _player;
      if (p is VolumeAware) (p as VolumeAware).volume = effectsVolume;
      await p.play(effect);
    } catch (_) {
      // نتجاهل أي خطأ صوتي.
    }
  }
}
