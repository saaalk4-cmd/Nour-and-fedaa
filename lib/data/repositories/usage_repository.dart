
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

  /// ثواني الاستخدام لكل يوم من آخر [days] يومًا، الأقدم أولًا (اليوم آخرها).
  Future<List<(DateTime, int)>> lastDays(int childId, int days,
      {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final out = <(DateTime, int)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = base.subtract(Duration(days: i));
      out.add((d, await secondsOn(childId, d)));
    }
    return out;
  }
}
