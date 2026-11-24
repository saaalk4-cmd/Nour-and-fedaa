import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class UsageRepository {
  Future<void> add(int childId, int seconds, {DateTime? now}) async {
    final db = await AppDatabase.instance.database;
    final day = dayKey(now ?? DateTime.now());
    await db.rawInsert(
      'INSERT INTO usage_log(child_id, day, seconds) VALUES(?, ?, ?) '
      'ON CONFLICT(child_id, day) DO UPDATE SET seconds = seconds + excluded.seconds',
      [childId, day, seconds],
    );
  }

  Future<int> secondsOn(int childId, DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'usage_log',
      columns: ['seconds'],
      where: 'child_id = ? AND day = ?',
      whereArgs: [childId, dayKey(day)],
    );
    return rows.isEmpty ? 0 : rows.first['seconds']! as int;
  }
}
