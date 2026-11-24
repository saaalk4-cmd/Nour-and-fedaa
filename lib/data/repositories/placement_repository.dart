import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/age_band.dart';
import '../../domain/level_check.dart';
import '../db/app_database.dart';

class PlacementRepository {
  PlacementRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// اختبار الفئة، أو null إن لم يوجد (مثل البراعم: يبدؤون من البداية).
  Future<LevelCheck?> checkFor(AgeBand band) async {
    try {
      final raw =
          await _bundle.loadString('assets/content/levelcheck/${band.name}.json');
      return LevelCheck.fromJsonString(raw);
    } on FlutterError {
      return null;
    }
  }

  Future<void> save(int childId, Map<String, int> levels) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    levels.forEach((track, level) => batch.insert(
          'placement',
          {'child_id': childId, 'track': track, 'level': level},
          conflictAlgorithm: ConflictAlgorithm.replace,
        ));
    await batch.commit(noResult: true);
  }

  /// مستوى البداية لكل مسار؛ المسار غير المحدد يبدأ من ١.
  Future<Map<String, int>> levels(int childId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db
        .query('placement', where: 'child_id = ?', whereArgs: [childId]);
    return {
      for (final r in rows) r['track']! as String: r['level']! as int,
    };
  }
}
