import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/repositories/badge_repository.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    await databaseFactory
        .setDatabasesPath(Directory.systemTemp.createTempSync('buraq_test').path);
    await AppDatabase.instance.close();
  });

  test('adab lessons exist for toddlers with verified-source notes', () async {
    final repo = LessonRepository();
    final list = await repo.bySection('t_adab', AgeBand.buraem);
    expect(list.map((l) => l.id), [
      't_adab_after_meal',
      't_adab_food',
      't_adab_greet',
      't_adab_sleep',
      't_adab_sneeze',
    ]);
    for (final l in list) {
      expect(l.sourceType, 'sahih_sunnah');
      expect(l.sourceNote, contains('صحيح البخاري'));
      expect(l.contentVerified, isFalse);
    }
    expect(await repo.bySection('t_adab', AgeBand.atfal), isEmpty);
    expect((await repo.bySection('t_listen', AgeBand.buraem)).length, 1);
  });

  test('badges are granted once, only when earned', () async {
    final childRepo = ChildRepository();
    final id = await childRepo.add(const ChildDraft(
        nickname: 'ن', avatar: 'star', birthYear: 2022, birthMonth: 1));
    final badges = BadgeRepository();
    expect(await badges.evaluate(id), isEmpty);

    await ProgressRepository().complete(childId: id, lessonId: 'a', stars: 3);
    expect((await badges.evaluate(id)).map((b) => b.id), ['first_lesson']);
    expect(await badges.evaluate(id), isEmpty);

    for (final l in ['b', 'c']) {
      await ProgressRepository().complete(childId: id, lessonId: l, stars: 3);
    }
    await ProgressRepository().complete(childId: id, lessonId: 'd', stars: 3);
    // ١٢ نجمة الآن
    expect((await badges.evaluate(id)).map((b) => b.id), ['ten_stars']);
    expect(await badges.earned(id), ['first_lesson', 'ten_stars']);
  });
}
