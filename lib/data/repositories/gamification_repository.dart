import 'package:sqflite/sqflite.dart';

import '../../domain/gamification/level_system.dart';
import '../../domain/gamification/quests.dart';
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
      lastActiveDay: r['last_active_day'] as String?,
    );
  }

  Future<void> _ensureQuestRows(
    DatabaseExecutor db,
    int childId,
    String day,
    List<QuestDef> defs,
  ) async {
    for (final d in defs) {
      await db.insert(
        'daily_quests',
        {'child_id': childId, 'day': day, 'quest_id': d.id, 'progress': 0, 'target': d.target},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await db.insert(
      'daily_quests',
      {'child_id': childId, 'day': day, 'quest_id': DailyQuests.bonusId, 'progress': 0, 'target': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> _ageOf(DatabaseExecutor db, int childId) async {
    final rows = await db.query('children', columns: ['age'], where: 'id = ?', whereArgs: [childId]);
    return rows.isEmpty ? 5 : (rows.first['age'] as int);
  }

  /// مهام اليوم للطفلة (تُنشأ تلقائيًا عند أول طلب في اليوم).
  Future<DailyQuestsState> dailyQuests(int childId, {DateTime? now}) async {
    final db = await AppDatabase.instance.database;
    final today = dayKey(now ?? DateTime.now());
    final defs = DailyQuests.forAge(await _ageOf(db, childId));
    await _ensureQuestRows(db, childId, today, defs);
    final rows = await db.query(
      'daily_quests',
      where: 'child_id = ? AND day = ?',
      whereArgs: [childId, today],
    );
    final progressById = {
      for (final r in rows) r['quest_id']! as String: (r['progress'] as int?) ?? 0,
    };
    return DailyQuestsState(
      quests: [
        for (final d in defs) QuestProgress(def: d, progress: progressById[d.id] ?? 0),
      ],
      bonusGiven: (progressById[DailyQuests.bonusId] ?? 0) > 0,
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

      // مهام اليوم: نحدّث التقدم، وإذا اكتملت كلها نعطي مكافأة يومية مرة واحدة.
      final defs = DailyQuests.forAge(await _ageOf(txn, childId));
      await _ensureQuestRows(txn, childId, today, defs);
      final questRows = await txn.query(
        'daily_quests',
        where: 'child_id = ? AND day = ?',
        whereArgs: [childId, today],
      );
      final current = {
        for (final r in questRows) r['quest_id']! as String: (r['progress'] as int?) ?? 0,
      };
      var allDone = true;
      for (final d in defs) {
        final before = current[d.id] ?? 0;
        final after = DailyQuests.applyEvent(
          d.id,
          before,
          d.target,
          lessons: 1,
          correct: firstTryCorrect,
          xp: reward.xp,
        );
        if (after != before) {
          await txn.update(
            'daily_quests',
            {'progress': after},
            where: 'child_id = ? AND day = ? AND quest_id = ?',
            whereArgs: [childId, today, d.id],
          );
        }
        if (after < d.target) allDone = false;
      }
      final bonusAlreadyGiven = (current[DailyQuests.bonusId] ?? 0) > 0;
      final grantBonus = allDone && !bonusAlreadyGiven;
      if (grantBonus) {
        await txn.update(
          'daily_quests',
          {'progress': 1},
          where: 'child_id = ? AND day = ? AND quest_id = ?',
          whereArgs: [childId, today, DailyQuests.bonusId],
        );
      }
      final bonusXp = grantBonus ? DailyQuests.bonusXp : 0;
      final bonusStars = grantBonus ? DailyQuests.bonusStars : 0;

      final oldXp = (g['xp'] as int?) ?? 0;
      final newXp = oldXp + reward.xp + bonusXp;
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
          'stars': ((g['stars'] as int?) ?? 0) + reward.stars + bonusStars,
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
        [reward.stars + bonusStars, reward.xp + bonusXp, childId],
      );

      return LessonCompletion(
        reward: reward,
        oldLevel: LevelSystem.levelForXp(oldXp),
        newLevel: LevelSystem.levelForXp(newXp),
        totalXp: newXp,
        streak: streak,
        bonusXp: bonusXp,
        bonusStars: bonusStars,
      );
    });
  }
}
