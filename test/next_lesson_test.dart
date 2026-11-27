import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/data/repositories/placement_repository.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/features/home/next_lesson.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    await AppDatabase.instance.close();
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('buraq_test').path);
  });

  Future<(ProviderContainer, int)> kid(int age) async {
    final id = await ChildRepository().add(ChildDraft(
        nickname: 'ن',
        avatar: 'star',
        birthYear: DateTime.now().year - age,
        birthMonth: 1));
    final c = ProviderContainer();
    c.read(selectedChildIdProvider.notifier).state = id;
    return (c, id);
  }

  placementTests();

  test('5-7: starts with the first Arabic lesson, then moves on', () async {
    final (c, id) = await kid(6);
    addTearDown(c.dispose);
    var next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.id, 'a_arabic_letters_1');
    expect(next.done, 0);
    expect(next.total, greaterThan(10));

    await ProgressRepository()
        .complete(childId: id, lessonId: 'a_arabic_letters_1', stars: 3);
    c.invalidate(nextLessonProvider);
    next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.id, 'a_arabic_letters_2');
    expect(next.done, 1);
  });

  test('a section turned off by the parent is skipped', () async {
    await SettingsRepository().setSectionEnabled(SectionIds.arabic, false);
    final (c, _) = await kid(6);
    addTearDown(c.dispose);
    final next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.section, isNot(SectionIds.arabic));
  });

  test('12-14 gets its own band lessons', () async {
    final (c, _) = await kid(13);
    addTearDown(c.dispose);
    final next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.id, startsWith('m_'));
  });
}

void placementTests() {
  test('the level test result skips to the child level in that track', () async {
    final id = await ChildRepository().add(ChildDraft(
        nickname: 'ن',
        avatar: 'star',
        birthYear: DateTime.now().year - 6,
        birthMonth: 1));
    await PlacementRepository().save(id, {'arabic': 2});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedChildIdProvider.notifier).state = id;
    final next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.id, 'a_arabic_words_1');
    expect(next.lesson!.level, 2);
  });

  test('a level-3 placement starts at the first level-3 lesson', () async {
    final id = await ChildRepository().add(ChildDraft(
        nickname: 'ن',
        avatar: 'star',
        birthYear: DateTime.now().year - 6,
        birthMonth: 1));
    await PlacementRepository().save(id, {'arabic': 3});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedChildIdProvider.notifier).state = id;
    final next = await c.read(nextLessonProvider.future);
    expect(next.lesson!.id, 'a_arabic_l3_build');
  });

  test('when no lesson matches the level, the first unfinished one is used',
      () async {
    final all = await LessonRepository().bySection('arabic', AgeBand.atfal);
    final pending = all.where((l) => l.level < 3).toList();
    expect(pickByPlacement(pending, {'arabic': 3}).id, 'a_arabic_letters_1');
  });
}
