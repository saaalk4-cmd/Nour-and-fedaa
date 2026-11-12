import '../db/app_database.dart';
import '../models/child.dart';

class ChildRepository {
  Future<List<Child>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('children', orderBy: 'age DESC');
    return rows.map(Child.fromMap).toList();
  }

  Future<Child?> byId(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('children', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Child.fromMap(rows.first);
  }

  Future<int> completedLessons(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM progress WHERE child_id = ? AND status = 'done'",
      [childId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// تعديل اسم الطفلة وعمرها (يغيّر المحتوى المعروض لها تلقائيًا).
  Future<void> update(int id, {required String name, required int age}) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'children',
      {'name': name, 'age': age},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// يضيف ثواني استخدام ليوم معيّن (UPDATE ثم INSERT: متوافق مع كل إصدارات SQLite).
  Future<void> addUsage(int childId, int seconds, String day) async {
    final db = await AppDatabase.instance.database;
    final changed = await db.rawUpdate(
      'UPDATE usage_log SET seconds = seconds + ? WHERE child_id = ? AND day = ?',
      [seconds, childId, day],
    );
    if (changed == 0) {
      await db.insert('usage_log', {'child_id': childId, 'day': day, 'seconds': seconds});
    }
  }

  Future<int> usageSecondsOn(int childId, String day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'usage_log',
      columns: ['seconds'],
      where: 'child_id = ? AND day = ?',
      whereArgs: [childId, day],
    );
    return rows.isEmpty ? 0 : ((rows.first['seconds'] as int?) ?? 0);
  }

  Future<int> totalSecondsUsed(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(seconds), 0) AS s FROM usage_log WHERE child_id = ?',
      [childId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }
}
