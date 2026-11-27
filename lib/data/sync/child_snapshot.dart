import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'cloud_id.dart';

/// تحويل بيانات طفل (الملف، التقدّم، المستوى، الشارات، المراجعة) إلى مستند
/// واحد للسحابة، ودمج مستند سحابي في القاعدة المحلية.
///
/// قاعدة الدمج: ما يوجد محليًا يبقى، وما ينقص يُضاف من السحابة،
/// والنجوم = الأكبر من النسختين. لا شيء يُحذف أثناء الدمج.
class ChildSnapshot {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, dynamic>?> export(int childId) async {
    final db = await _db;
    final rows =
        await db.query('children', where: 'id = ?', whereArgs: [childId]);
    if (rows.isEmpty) return null;
    final c = rows.first;
    var cloudId = c['cloud_id'] as String?;
    if (cloudId == null) {
      cloudId = newCloudId();
      await db.update('children', {'cloud_id': cloudId},
          where: 'id = ?', whereArgs: [childId]);
    }
    Future<List<Map<String, Object?>>> q(String t) =>
        db.query(t, where: 'child_id = ?', whereArgs: [childId]);

    return {
      'cloud_id': cloudId,
      'nickname': c['nickname'],
      'avatar': c['avatar'],
      'birth_year': c['birth_year'],
      'birth_month': c['birth_month'],
      'band_override': c['band_override'],
      'stars': c['stars'],
      'points': c['points'],
      'progress': {
        for (final r in await q('progress'))
          r['lesson_id']! as String: {
            'status': r['status'],
            'score': r['score'],
            'completed_at': r['completed_at'],
          }
      },
      'placement': {
        for (final r in await q('placement'))
          r['track']! as String: r['level']
      },
      'badges': {
        for (final r in await q('badges'))
          r['badge_id']! as String: r['earned_at']
      },
      'review': {
        for (final r in await q('review'))
          r['lesson_id']! as String: {'box': r['box'], 'due_day': r['due_day']}
      },
    };
  }

  /// يدمج مستندًا سحابيًا ويعيد المعرّف المحلي للطفل.
  Future<int> merge(Map<String, dynamic> d) async {
    final db = await _db;
    return db.transaction((txn) async {
      final cloudId = d['cloud_id'] as String;
      final existing = await txn
          .query('children', where: 'cloud_id = ?', whereArgs: [cloudId]);
      final cloudStars = (d['stars'] as num?)?.toInt() ?? 0;
      int id;
      if (existing.isEmpty) {
        id = await txn.insert('children', {
          'nickname': d['nickname'],
          'avatar': d['avatar'] ?? 'star',
          'birth_year': d['birth_year'],
          'birth_month': d['birth_month'],
          'band_override': d['band_override'],
          'stars': cloudStars,
          'points': (d['points'] as num?)?.toInt() ?? 0,
          'cloud_id': cloudId,
        });
      } else {
        id = existing.first['id']! as int;
        final localStars = existing.first['stars']! as int;
        if (cloudStars > localStars) {
          await txn.update('children', {'stars': cloudStars},
              where: 'id = ?', whereArgs: [id]);
        }
      }

      Map<String, dynamic> m(String k) =>
          Map<String, dynamic>.from((d[k] as Map?) ?? const {});
      const keep = ConflictAlgorithm.ignore;
      for (final e in m('progress').entries) {
        final v = Map<String, dynamic>.from(e.value as Map);
        await txn.insert(
            'progress',
            {
              'child_id': id,
              'lesson_id': e.key,
              'status': v['status'] ?? 'done',
              'score': (v['score'] as num?)?.toInt() ?? 0,
              'completed_at': v['completed_at'],
            },
            conflictAlgorithm: keep);
      }
      for (final e in m('placement').entries) {
        await txn.insert('placement',
            {'child_id': id, 'track': e.key, 'level': (e.value as num).toInt()},
            conflictAlgorithm: keep);
      }
      for (final e in m('badges').entries) {
        await txn.insert('badges',
            {'child_id': id, 'badge_id': e.key, 'earned_at': e.value},
            conflictAlgorithm: keep);
      }
      for (final e in m('review').entries) {
        final v = Map<String, dynamic>.from(e.value as Map);
        await txn.insert(
            'review',
            {
              'child_id': id,
              'lesson_id': e.key,
              'box': (v['box'] as num?)?.toInt() ?? 0,
              'due_day': v['due_day'],
            },
            conflictAlgorithm: keep);
      }
      return id;
    });
  }
}
