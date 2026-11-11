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

  Future<int> totalSecondsUsed(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(seconds), 0) AS s FROM usage_log WHERE child_id = ?',
      [childId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }
}
