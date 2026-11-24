import '../db/app_database.dart';
import '../models/child.dart';
import '../../domain/age_band.dart';

class ChildRepository {
  Future<List<Child>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('children', orderBy: 'birth_year ASC, id ASC');
    return rows.map(Child.fromMap).toList();
  }

  Future<Child?> byId(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('children', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Child.fromMap(rows.first);
  }

  /// يحفظ طفلًا جديدًا ويعيد معرّفه.
  Future<int> add(ChildDraft draft, {AgeBand? bandOverride}) async {
    assert(draft.isComplete);
    final db = await AppDatabase.instance.database;
    return db.insert('children', {
      'nickname': draft.nickname.trim(),
      'avatar': draft.avatar,
      'birth_year': draft.birthYear,
      'birth_month': draft.birthMonth,
      'band_override': bandOverride?.name,
    });
  }

  Future<void> setBand(int id, AgeBand? band) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'children',
      {'band_override': band?.name},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// يحذف الطفل وكل بياناته المرتبطة.
  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final t in ['progress', 'badges', 'usage_log', 'placement', 'review']) {
        await txn.delete(t, where: 'child_id = ?', whereArgs: [id]);
      }
      await txn.delete('children', where: 'id = ?', whereArgs: [id]);
    });
  }
}
