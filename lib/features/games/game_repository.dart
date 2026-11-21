import 'package:sqflite/sqflite.dart';

import '../../data/db/app_database.dart';

/// نتيجة حفظ جولة لعب: كم نجمة جديدة أُضيفت، وهل هذه أفضل نتيجة.
class GameSaveResult {
  const GameSaveResult({required this.previousBest, required this.newBest, required this.addedStars});

  final int previousBest;
  final int newBest;

  /// النجوم الإضافية فوق أفضل نتيجة سابقة (تُضاف لنجوم الطفلة؛ إعادة اللعب لا تكرر المكافأة).
  final int addedStars;
}

/// تقدم الألعاب (بلا إنترنت): لكل طفلة ولعبة ومستوى أفضل نجوم وعدد مرات اللعب.
class GameRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// game_id → (level_key → best_stars)
  Future<Map<String, Map<String, int>>> progress(int childId) async {
    final rows = await (await _db).query('game_progress', where: 'child_id = ?', whereArgs: [childId]);
    final out = <String, Map<String, int>>{};
    for (final r in rows) {
      (out[r['game_id'] as String] ??= {})[r['level_key'] as String] = r['best_stars'] as int;
    }
    return out;
  }

  Future<GameSaveResult> saveRound({
    required int childId,
    required String gameId,
    required String levelKey,
    required int stars,
    DateTime? now,
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query('game_progress',
          where: 'child_id = ? AND game_id = ? AND level_key = ?', whereArgs: [childId, gameId, levelKey]);
      final prev = rows.isEmpty ? 0 : rows.first['best_stars'] as int;
      final plays = rows.isEmpty ? 0 : rows.first['plays'] as int;
      final best = stars > prev ? stars : prev;
      await txn.insert(
        'game_progress',
        {
          'child_id': childId,
          'game_id': gameId,
          'level_key': levelKey,
          'best_stars': best,
          'plays': plays + 1,
          'last_played': (now ?? DateTime.now()).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final added = best - prev;
      if (added > 0) {
        await txn.rawInsert('INSERT OR IGNORE INTO gamification(child_id) VALUES(?)', [childId]);
        await txn.rawUpdate('UPDATE gamification SET stars = stars + ? WHERE child_id = ?', [added, childId]);
      }
      return GameSaveResult(previousBest: prev, newBest: best, addedStars: added);
    });
  }

  /// كل مرات اللعب لطفلة (للوحة الأهل).
  Future<int> totalPlays(int childId) async {
    final r = await (await _db).rawQuery('SELECT COALESCE(SUM(plays),0) AS n FROM game_progress WHERE child_id = ?', [childId]);
    return (r.first['n'] as num).toInt();
  }
}
