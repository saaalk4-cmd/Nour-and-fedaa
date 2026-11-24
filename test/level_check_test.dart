import 'dart:io';
import 'dart:convert';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/repositories/placement_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/level_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LevelCheck _check() => LevelCheck.fromJsonString(jsonEncode({
      'band': 'atfal',
      'questions': [
        for (final t in ['quran', 'salah'])
          for (var l = 1; l <= 3; l++)
            {
              'track': t,
              'level': l,
              'text': 'q',
              'options': ['a', 'b'],
              'answer': 0,
              'source_type': 'educational',
            }
      ],
    }));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('placement counts consecutive correct from level 1, capped at 3', () {
    final c = _check(); // أسئلة quran: 0..2 بعد الترتيب بحسب المستوى
    final qIdx = [
      for (var i = 0; i < c.questions.length; i++)
        if (c.questions[i].track == 'quran') i
    ];
    final sIdx = [
      for (var i = 0; i < c.questions.length; i++)
        if (c.questions[i].track == 'salah') i
    ];
    // quran: كلها صحيحة؛ salah: الأول صحيح والثاني خطأ والثالث صحيح
    final p = c.placement({
      for (final i in qIdx) i: 0,
      sIdx[0]: 0,
      sIdx[1]: 1,
      sIdx[2]: 0,
    });
    expect(p['quran'], 3);
    expect(p['salah'], 2);
    expect(c.placement({})['quran'], 1);
  });

  test('question without valid source_type is rejected', () {
    expect(
      () => LevelQuestion.fromJson({
        'track': 'quran',
        'level': 1,
        'text': 'q',
        'options': ['a', 'b'],
        'answer': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => LevelQuestion.fromJson({
        'track': 'quran',
        'level': 1,
        'text': 'q',
        'options': ['a', 'b'],
        'answer': 5,
        'source_type': 'quran',
      }),
      throwsFormatException,
    );
  });

  test('bundled checks parse, cover all tracks, no check for buraem', () async {
    final repo = PlacementRepository();
    for (final b in [AgeBand.atfal, AgeBand.nashia, AgeBand.murahiqun]) {
      final c = await repo.checkFor(b);
      expect(c, isNotNull, reason: b.name);
      for (final t in placementTracks) {
        final lv = c!.questions.where((q) => q.track == t).map((q) => q.level);
        expect(lv.toList()..sort(), [1, 2, 3], reason: '${b.name}/$t');
      }
    }
    expect(await repo.checkFor(AgeBand.buraem), isNull);
  });

  group('storage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      await databaseFactory
          .setDatabasesPath(Directory.systemTemp.createTempSync('buraq_test').path);
      await AppDatabase.instance.close();
    });

    test('save and read levels, overwrite on retake', () async {
      final repo = PlacementRepository();
      await repo.save(1, {'quran': 2, 'salah': 1});
      await repo.save(1, {'quran': 3});
      expect(await repo.levels(1), {'quran': 3, 'salah': 1});
      expect(await repo.levels(2), isEmpty);
    });
  });
}
