import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

class ProgressRepository {
  Future<bool> isDone(int childId, String lessonId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'progress',
      where: "child_id = ? AND lesson_id = ? AND status = 'done'",
      whereArgs: [childId, lessonId],
    );
    return rows.isNotEmpty;
  }

  /// يسجّل إتمام الدرس. النجوم تُمنح أول مرة فقط؛ تكرار الدرس لا يزيدها.
  /// يعيد عدد النجوم التي أُضيفت فعليًا.
  Future<int> complete({
    required int childId,
    required String lessonId,
    required int stars,
    DateTime? now,
  }) async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final done = await txn.query(
        'progress',
        where: "child_id = ? AND lesson_id = ? AND status = 'done'",
        whereArgs: [childId, lessonId],
      );
      if (done.isNotEmpty) return 0;
      await txn.insert(
        'progress',
        {
          'child_id': childId,
          'lesson_id': lessonId,
          'status': 'done',
          'score': stars,
          'completed_at': (now ?? DateTime.now()).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.rawUpdate(
        'UPDATE children SET stars = stars + ? WHERE id = ?',
        [stars, childId],
      );
      return stars;
    });
  }
}
