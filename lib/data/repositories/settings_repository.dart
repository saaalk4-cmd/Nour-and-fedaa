import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
