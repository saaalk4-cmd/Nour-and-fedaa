import 'package:sqflite/sqflite.dart';

import '../../domain/spaced_review.dart';
import '../db/app_database.dart';
import 'usage_repository.dart' show dayKey;

class ReviewRepository {
  /// معرّفات الدروس المستحقة للمراجعة اليوم أو قبله، الأقدم أولًا.
  Future<List<String>> due(int childId, {DateTime? now}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'review',
      columns: ['lesson_id'],
      where: 'child_id = ? AND due_day <= ?',
      whereArgs: [childId, dayKey(now ?? DateTime.now())],
      orderBy: 'due_day ASC, lesson_id ASC',
    );
    return rows.map((r) => r['lesson_id']! as String).toList();
  }

  /// يسجّل نتيجة مراجعة ويحدّد موعد المرة التالية.
  /// لفئة البراعم لا يُحكم على الطفل: تُحسب كل مراجعة منجزة ناجحة.
  Future<void> recordReview(
    int childId,
    String lessonId, {
    required bool remembered,
    DateTime? now,
  }) async {
    final db = await AppDatabase.instance.database;
    final today = now ?? DateTime.now();
    final rows = await db.query('review',
        where: 'child_id = ? AND lesson_id = ?', whereArgs: [childId, lessonId]);
    if (rows.isEmpty) return;
    final box = nextBox(rows.first['box']! as int, remembered: remembered);
    await db.update(
      'review',
      {'box': box, 'due_day': dayKey(dueDateFor(box, today))},
      where: 'child_id = ? AND lesson_id = ?',
      whereArgs: [childId, lessonId],
    );
  }

  /// يضيف الدرس لجدول المراجعة (الصندوق الأول) إن لم يكن فيه.
  static Future<void> scheduleInTxn(
    DatabaseExecutor txn,
    int childId,
    String lessonId,
    DateTime now,
  ) =>
      txn.insert(
        'review',
        {
          'child_id': childId,
          'lesson_id': lessonId,
          'box': 0,
          'due_day': dayKey(dueDateFor(0, now)),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
}
