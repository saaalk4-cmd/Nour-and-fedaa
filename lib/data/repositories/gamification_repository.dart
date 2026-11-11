import 'package:sqflite/sqflite.dart';

import '../../domain/gamification/level_system.dart';
import '../../domain/gamification/streak.dart';
import '../../domain/gamification/xp_rules.dart';
import '../db/app_database.dart';
import '../models/gamification.dart';
import '../models/lesson_completion.dart';

class GamificationRepository {
  Future<GamificationProfile> profile(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('gamification', where: 'child_id = ?', whereArgs: [childId]);
    if (rows.isEmpty) {
      await db.insert('gamification', {'child_id': childId}, conflictAlgorithm: ConflictAlgorithm.ignore);
      return const GamificationProfile(xp: 0, stars: 0, level: 1, streakDays: 0, dailyQuestsCompleted: 0, totalLessons: 0);
    }
    final r = rows.first;
    final xp = (r['xp'] as int?) ?? 0;
    return GamificationProfile(
      xp: xp,
      stars: (r['stars'] as int?) ?? 0,
      level: LevelSystem.levelForXp(xp),
      streakDays: (r['streak_days'] as int?) ?? 0,
      dailyQuestsCompleted: (r['daily_quests_completed'] as int?) ?? 0,
      totalLessons: (r['total_lessons'] as int?) ?? 0,
      bestStreak: (r['best_streak'] as int?) ?? 0,
    );
  }

  Future<Set<String>> completedLessonIds(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'progress',
      columns: ['lesson_id'],
      where: "child_id = ? AND status = 'done'",
      whereArgs: [childId],
    );
    return rows.map((r) => r['lesson_id']! as String).toSet();
  }

  /// يسجّل إكمال درس في معاملة واحدة (كلها أو لا شيء):
  /// التقدم، XP، النجوم، السلسلة، وعدد الدروس.
  Future<LessonCompletion> completeLesson({
    required int childId,
    required String lessonId,
    required int firstTryCorrect,
    required int totalQuestions,
    DateTime? now,
  }) async {
    final db = await AppDatabase.instance.database;
    final time = now ?? DateTime.now();
    final today = dayKey(time);

    return db.transaction<LessonCompletion>((txn) async {
      await txn.insert(
        'gamification',
        {'child_id': childId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final g = (await txn.query('gamification', where: 'child_id = ?', whereArgs: [childId])).first;
      final prev = await txn.query(
        'progress',
        where: 'child_id = ? AND lesson_id = ?',
        whereArgs: [childId, lessonId],
      );
      final isFirst = prev.isEmpty || prev.first['status'] != 'done';

      final reward = XpRules.forLesson(
        firstTryCorrect: firstTryCorrect,
        totalQuestions: totalQuestions,
        isFirstCompletion: isFirst,
      );

      final oldXp = (g['xp'] as int?) ?? 0;
      final newXp = oldXp + reward.xp;
      final streak = StreakCalculator.update(
        lastDay: g['last_active_day'] as String?,
        today: today,
        current: (g['streak_days'] as int?) ?? 0,
        best: (g['best_streak'] as int?) ?? 0,
      );
      final prevScore = prev.isEmpty ? 0 : ((prev.first['score'] as int?) ?? 0);

      await txn.insert(
        'progress',
        {
          'child_id': childId,
          'lesson_id': lessonId,
          'status': 'done',
          'score': firstTryCorrect > prevScore ? firstTryCorrect : prevScore,
          'completed_at': time.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'gamification',
        {
          'xp': newXp,
          'stars': ((g['stars'] as int?) ?? 0) + reward.stars,
          'streak_days': streak.current,
          'best_streak': streak.best,
          'last_active_day': today,
          'total_lessons': ((g['total_lessons'] as int?) ?? 0) + (isFirst ? 1 : 0),
        },
        where: 'child_id = ?',
        whereArgs: [childId],
      );
      // نُبقي جدول children متسقًا (لوحة ولي الأمر تقرأ منه حاليًا).
      await txn.rawUpdate(
        'UPDATE children SET stars = stars + ?, points = points + ? WHERE id = ?',
        [reward.stars, reward.xp, childId],
      );

      return LessonCompletion(
        reward: reward,
        oldLevel: LevelSystem.levelForXp(oldXp),
        newLevel: LevelSystem.levelForXp(newXp),
        totalXp: newXp,
        streak: streak,
      );
    });
  }
}
