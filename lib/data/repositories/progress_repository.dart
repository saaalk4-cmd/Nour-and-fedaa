import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'review_repository.dart';

class ProgressRepository {
  /// الدروس المكتملة مع وقت إتمامها، الأحدث أولًا.
  Future<List<(String, DateTime?)>> completed(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('progress',
        columns: ['lesson_id', 'completed_at'],
        where: "child_id = ? AND status = 'done'",
        whereArgs: [childId],
        orderBy: 'completed_at DESC');
    return [
      for (final r in rows)
        (
          r['lesson_id']! as String,
          DateTime.tryParse((r['completed_at'] as String?) ?? '')
        )
    ];
  }

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
      await ReviewRepository.scheduleInTxn(
          txn, childId, lessonId, now ?? DateTime.now());
      return stars;
    });
  }
}
