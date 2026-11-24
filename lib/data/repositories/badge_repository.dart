import 'package:sqflite/sqflite.dart';

import '../../domain/badges.dart';
import '../db/app_database.dart';

class BadgeRepository {
  Future<List<String>> earned(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('badges',
        columns: ['badge_id'],
        where: 'child_id = ?',
        whereArgs: [childId],
        orderBy: 'earned_at ASC');
    return rows.map((r) => r['badge_id']! as String).toList();
  }

  /// يمنح كل شارة استُحقت ولم تُمنح بعد، ويعيد الجديد منها فقط.
  Future<List<BadgeDef>> evaluate(int childId, {DateTime? now}) async {
    final db = await AppDatabase.instance.database;
    final lessons = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM progress WHERE child_id = ? AND status = 'done'",
            [childId])) ??
        0;
    final stars = Sqflite.firstIntValue(
            await db.rawQuery('SELECT stars FROM children WHERE id = ?', [childId])) ??
        0;
    final stats = BadgeStats(lessonsDone: lessons, stars: stars);
    final have = (await earned(childId)).toSet();
    final fresh = <BadgeDef>[];
    for (final b in badgeDefs) {
      if (have.contains(b.id) || !b.earnedBy(stats)) continue;
      await db.insert(
        'badges',
        {
          'child_id': childId,
          'badge_id': b.id,
          'earned_at': (now ?? DateTime.now()).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      fresh.add(b);
    }
    return fresh;
  }
}
