import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'quran_source.dart';

class SqliteQuranCache implements QuranCacheStore {
  @override
  Future<String?> read(int surah) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('quran_cache',
          columns: ['payload'], where: 'surah = ?', whereArgs: [surah]);
      return rows.isEmpty ? null : rows.first['payload'] as String;
    } catch (_) {
      return null; // مثل الويب: بلا قاعدة محلية، نعتمد على الإنترنت.
    }
  }

  @override
  Future<void> write(int surah, String payload) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'quran_cache',
        {
          'surah': surah,
          'payload': payload,
          'fetched_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {/* الحفظ اختياري */}
  }
}
