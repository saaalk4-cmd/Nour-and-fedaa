import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/audio/voice_service.dart' show VoiceSettings;
import '../../domain/time_guard.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

/// معرّفات أقسام التطبيق الرئيسية.
class SectionIds {
  static const quran = 'quran';
  static const prayer = 'prayer';
  static const adhkar = 'adhkar';
  static const akhlaq = 'akhlaq';
  static const seerah = 'seerah';
  static const figures = 'figures';
  static const prophets = 'prophets';
  static const learn = 'learn';
  static const achievements = 'achievements';

  static const all = [
    quran,
    prayer,
    adhkar,
    akhlaq,
    seerah,
    figures,
    prophets,
    learn,
    achievements,
  ];
}

class SettingsRepository {
  Future<String?> _get(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- PIN ----------

  Future<bool> hasPin() async => (await _get('pin_hash')) != null;

  Future<void> setPin(String pin) async {
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _set('pin_salt', salt);
    await _set('pin_hash', _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _get('pin_salt');
    final hash = await _get('pin_hash');
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  // ---------- المقدمة السينمائية ----------

  /// تُعدّ مشاهَدة فقط بعد وصولها للنهاية (أو تخطّيها بعد معظمها).
  Future<bool> cinematicIntroSeen() async => (await _get('cinematic_intro_seen')) == '1';

  Future<void> setCinematicIntroSeen(bool seen) => _set('cinematic_intro_seen', seen ? '1' : '0');

  // ---------- الصوت ----------

  /// الصوت مفعّل افتراضيًا، ويتحكم به ولي الأمر.
  Future<bool> soundEnabled() async => (await _get('sound_enabled')) != '0';

  Future<void> setSoundEnabled(bool enabled) =>
      _set('sound_enabled', enabled ? '1' : '0');

  // ---------- النطق (قراءة الكلام بصوت عالٍ) ----------

  /// مفعّل افتراضيًا: الطفلة قد لا تقرأ ولا يوجد والد بجانبها.
  Future<bool> voiceEnabled() async => (await _get('voice_enabled')) != '0';

  Future<void> setVoiceEnabled(bool enabled) =>
      _set('voice_enabled', enabled ? '1' : '0');

  /// إعدادات الصوت (وقفة، سرعة، علو، قراءة تلقائية). القيم الافتراضية مناسبة للأطفال.
  Future<VoiceSettings> voiceSettings() async {
    final pause = int.tryParse(await _get('voice_pause_ms') ?? '') ?? 1000;
    final rate = double.tryParse(await _get('voice_rate') ?? '') ?? VoiceSettings.normal;
    final vv = double.tryParse(await _get('voice_volume') ?? '') ?? 1.0;
    final ev = double.tryParse(await _get('effects_volume') ?? '') ?? 1.0;
    final auto = (await _get('auto_read')) != '0';
    return VoiceSettings(
      pauseMs: pause.clamp(0, 4000),
      rate: rate.clamp(0.25, 0.8),
      voiceVolume: vv.clamp(0.0, 1.0),
      effectsVolume: ev.clamp(0.0, 1.0),
      autoRead: auto,
    );
  }

  Future<void> saveVoiceSettings(VoiceSettings s) async {
    await _set('voice_pause_ms', '${s.pauseMs}');
    await _set('voice_rate', '${s.rate}');
    await _set('voice_volume', '${s.voiceVolume}');
    await _set('effects_volume', '${s.effectsVolume}');
    await _set('auto_read', s.autoRead ? '1' : '0');
  }

  // ---------- الوقت ----------

  Future<TimeSettings> timeSettings() async => TimeSettings(
        dailyLimitMin: int.tryParse(await _get('daily_limit_min') ?? '') ?? 0,
        quietFromMin: int.tryParse(await _get('quiet_from_min') ?? '') ?? -1,
        quietToMin: int.tryParse(await _get('quiet_to_min') ?? '') ?? -1,
        breakEveryMin: int.tryParse(await _get('break_every_min') ?? '') ?? 15,
      );

  Future<void> saveTimeSettings(TimeSettings s) async {
    await _set('daily_limit_min', '${s.dailyLimitMin}');
    await _set('quiet_from_min', '${s.quietFromMin}');
    await _set('quiet_to_min', '${s.quietToMin}');
    await _set('break_every_min', '${s.breakEveryMin}');
  }

  /// دقائق إضافية منحها ولي الأمر اليوم (بعد الحد).
  Future<int> extraMinutes(String day) async => (await _get('extra_min_$day')) == null ? 0 : int.tryParse((await _get('extra_min_$day'))!) ?? 0;

  Future<void> grantExtraMinutes(String day, int minutes) async => _set('extra_min_$day', '${await extraMinutes(day) + minutes}');

  /// السماح لباقي اليوم (يوقف الحد وساعات المنع حتى الغد).
  Future<bool> overriddenToday(String day) async => (await _get('time_override_day')) == day;

  Future<void> overrideToday(String day) => _set('time_override_day', day);

  // ---------- الألعاب والإنترنت ----------

  Future<bool> gamesEnabled() async => (await _get('games_enabled')) != '0';

  Future<void> setGamesEnabled(bool v) => _set('games_enabled', v ? '1' : '0');

  /// تحديث الألعاب الجديدة: auto (تلقائيًا عند فتح الألعاب) | manual (بالزر فقط) | off (مقفول).
  Future<String> packMode() async => (await _get('pack_mode')) ?? 'auto';

  Future<void> setPackMode(String v) => _set('pack_mode', v);

  // ---------- الشكل والعرض ----------

  /// تقليل الحركة (بلا كونفيتي ولا رقص) للبنت التي تتشتت.
  Future<bool> reduceMotion() async => (await _get('reduce_motion')) == '1';

  Future<void> setReduceMotion(bool v) => _set('reduce_motion', v ? '1' : '0');

  /// حجم الخط: 1.0 عادي، 1.2 كبير.
  Future<double> fontScale() async => (double.tryParse(await _get('font_scale') ?? '') ?? 1.0).clamp(0.9, 1.4);

  Future<void> setFontScale(double v) => _set('font_scale', '$v');

  /// الصوت العربي الذي اختاره الأهل (null = تلقائي: أوضح صوت على الجهاز).
  Future<String?> ttsVoice() async {
    final v = await _get('tts_voice');
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setTtsVoice(String? name) => _set('tts_voice', name ?? '');

  /// قيمة عامة (لحزم المحتوى المنزّلة وما شابه).
  Future<String?> getValue(String key) => _get(key);

  Future<void> setValue(String key, String value) => _set(key, value);

  // ---------- الأقسام ----------

  Future<bool> isSectionEnabled(String id) async =>
      (await _get('section_off_$id')) != '1';

  Future<void> setSectionEnabled(String id, bool enabled) =>
      _set('section_off_$id', enabled ? '0' : '1');

  Future<Map<String, bool>> sectionStates() async {
    final result = <String, bool>{};
    for (final id in SectionIds.all) {
      result[id] = await isSectionEnabled(id);
    }
    return result;
  }
}
