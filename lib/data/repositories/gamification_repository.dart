import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/gamification.dart';

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
      level: xp ~/ 100 + 1,
      streakDays: (r['streak_days'] as int?) ?? 0,
      dailyQuestsCompleted: (r['daily_quests_completed'] as int?) ?? 0,
      totalLessons: (r['total_lessons'] as int?) ?? 0,
    );
  }
}
