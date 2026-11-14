import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/repositories/child_repository.dart';
import 'package:nourfadaa/data/repositories/gamification_repository.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبارات تكاملية على SQLite حقيقي (بدون جهاز): حفظ التقدم، المكافآت،
/// الشارات، السلسلة، الترقية من إصدار قديم، وPIN.
void main() {
  final game = GamificationRepository();
  final children = ChildRepository();
  final settings = SettingsRepository();

  setUpAll(() {
    sqfliteFfiInit();
    // مجلد قاعدة بيانات خاص بهذا الملف: ملفات الاختبار تعمل بالتوازي
    // ولا يجوز أن تتشارك ملف SQLite واحدًا (database is locked).
    final dir = Directory.systemTemp.createTempSync('nourfadaa_test_');
    databaseFactoryFfi.setDatabasesPath(dir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.resetForTest();
  });

  Future<Child> byName(String name) async =>
      (await children.all()).firstWhere((c) => c.name == name);

  test('fresh database seeds both daughters with the right ages', () async {
    expect((await byName('فداء')).age, 5);
    expect((await byName('نور')).age, 3);
  });

  test('first perfect lesson: XP, stars, daily bonus, badges and persistence', () async {
    final fedaa = await byName('فداء');
    final r = await game.completeLesson(
      childId: fedaa.id,
      lessonId: 'learn_add_simple',
      firstTryCorrect: 3,
      totalQuestions: 3,
      now: DateTime(2026, 11, 12, 10),
    );

    expect(r.reward.xp, 30); // 10 + 3*5 + 5
    expect(r.reward.stars, 2);
    // فداء (5 سنوات): درس + 3 إجابات + 25 XP => تكتمل كل المهام فتأتي مكافأة اليوم
    expect(r.bonusXp, 10);
    expect(r.bonusStars, 1);
    expect(r.totalXp, 40);
    expect(
      r.newBadges.map((b) => b.id),
      containsAll(<String>['first_lesson', 'perfect_lesson', 'daily_hero']),
    );

    final profile = await game.profile(fedaa.id);
    expect(profile.xp, 40);
    expect(profile.stars, 3);
    expect(profile.totalLessons, 1);
    expect(profile.streakDays, 1);
    expect(await game.completedLessonIds(fedaa.id), {'learn_add_simple'});

    final entries = await game.progressEntries(fedaa.id);
    expect(entries.single.lessonId, 'learn_add_simple');
    expect(entries.single.score, 3);
    expect(entries.single.completedAt, isNotNull);

    final badges = await game.earnedBadges(fedaa.id);
    expect(badges.keys, containsAll(<String>['first_lesson', 'perfect_lesson', 'daily_hero']));

    final quests = await game.dailyQuests(fedaa.id, now: DateTime(2026, 11, 12, 11));
    expect(quests.allDone, isTrue);
    expect(quests.bonusGiven, isTrue);
    expect(quests.quests.length, 3);
  });

  test('younger child gets 2 quests and her bonus too', () async {
    final nour = await byName('نور');
    final r = await game.completeLesson(
      childId: nour.id,
      lessonId: 'learn_colors_basic',
      firstTryCorrect: 2,
      totalQuestions: 2,
      now: DateTime(2026, 11, 12, 10),
    );
    expect(r.reward.xp, 25); // 10 + 2*5 + 5
    expect(r.bonusXp, 10);
    final quests = await game.dailyQuests(nour.id, now: DateTime(2026, 11, 12, 10));
    expect(quests.quests.length, 2);
  });

  test('replay gives small XP, no stars, no second daily bonus', () async {
    final fedaa = await byName('فداء');
    final day = DateTime(2026, 11, 12, 10);
    await game.completeLesson(
      childId: fedaa.id,
      lessonId: 'learn_add_simple',
      firstTryCorrect: 3,
      totalQuestions: 3,
      now: day,
    );
    final again = await game.completeLesson(
      childId: fedaa.id,
      lessonId: 'learn_add_simple',
      firstTryCorrect: 3,
      totalQuestions: 3,
      now: day,
    );
    expect(again.reward.xp, 5);
    expect(again.reward.stars, 0);
    expect(again.bonusXp, 0);
    final profile = await game.profile(fedaa.id);
    expect(profile.totalLessons, 1);
    expect(profile.xp, 45);
    expect(profile.stars, 3);
  });

  test('children progress is independent (no mixing between sisters)', () async {
    final fedaa = await byName('فداء');
    final nour = await byName('نور');
    await game.completeLesson(
      childId: fedaa.id,
      lessonId: 'learn_add_simple',
      firstTryCorrect: 1,
      totalQuestions: 3,
      now: DateTime(2026, 11, 12, 10),
    );
    expect((await game.profile(nour.id)).xp, 0);
    expect(await game.completedLessonIds(nour.id), isEmpty);
  });

  test('streak extends daily, then welcomes back after a gap', () async {
    final nour = await byName('نور');
    Future<dynamic> complete(String lesson, DateTime when) => game.completeLesson(
          childId: nour.id,
          lessonId: lesson,
          firstTryCorrect: 1,
          totalQuestions: 2,
          now: when,
        );

    final a = await complete('l1', DateTime(2026, 11, 12, 9));
    expect(a.streak.current, 1);
    final b = await complete('l2', DateTime(2026, 11, 13, 9));
    expect(b.streak.current, 2);
    final c = await complete('l3', DateTime(2026, 11, 20, 9));
    expect(c.streak.welcomeBack, isTrue);
    expect(c.streak.current, 1);
    expect((await game.profile(nour.id)).bestStreak, 2);
  });

  test('level-up is detected when crossing 100 XP', () async {
    final nour = await byName('نور');
    final results = <dynamic>[];
    for (var i = 0; i < 4; i++) {
      results.add(await game.completeLesson(
        childId: nour.id,
        lessonId: 'lesson_$i',
        firstTryCorrect: 2,
        totalQuestions: 2,
        now: DateTime(2026, 11, 12, 10),
      ));
    }
    // 35 (مع مكافأة اليوم) + 25 + 25 + 25 = 110
    expect(results[2].leveledUp, isFalse);
    expect(results[3].leveledUp, isTrue);
    expect(results[3].newLevel, 2);
    expect((await game.profile(nour.id)).level, 2);
  });

  test('upgrades a version-1 database without losing data', () async {
    final dir = await getDatabasesPath();
    final old = await databaseFactory.openDatabase(
      p.join(dir, 'nourfadaa.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute('CREATE TABLE children(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,age INTEGER NOT NULL,stars INTEGER NOT NULL DEFAULT 0,points INTEGER NOT NULL DEFAULT 0)');
          await db.execute('CREATE TABLE progress(child_id INTEGER NOT NULL,lesson_id TEXT NOT NULL,status TEXT NOT NULL,score INTEGER NOT NULL DEFAULT 0,completed_at TEXT,PRIMARY KEY(child_id, lesson_id))');
          await db.execute('CREATE TABLE badges(child_id INTEGER NOT NULL,badge_id TEXT NOT NULL,earned_at TEXT NOT NULL,PRIMARY KEY(child_id, badge_id))');
          await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
          await db.execute('CREATE TABLE usage_log(child_id INTEGER NOT NULL,day TEXT NOT NULL,seconds INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(child_id, day))');
          await db.insert('children', {'name': 'فداء', 'age': 5, 'stars': 7});
          await db.insert('settings', {'key': 'pin_hash', 'value': 'keep-me'});
        },
      ),
    );
    await old.close();

    // الفتح عبر التطبيق يرقّي القاعدة إلى الإصدار الحالي.
    final fedaa = (await children.all()).single;
    expect(fedaa.stars, 7);

    final r = await game.completeLesson(
      childId: fedaa.id,
      lessonId: 'learn_letters_alef_ba_ta',
      firstTryCorrect: 3,
      totalQuestions: 3,
      now: DateTime(2026, 11, 12, 10),
    );
    expect(r.totalXp, greaterThan(0));
    expect((await game.profile(fedaa.id)).totalLessons, 1);
    expect(await settings.hasPin(), isTrue); // الإعدادات القديمة محفوظة
  });

  test('PIN is stored hashed, verified, and wrong PIN is rejected', () async {
    expect(await settings.hasPin(), isFalse);
    await settings.setPin('1234');
    expect(await settings.hasPin(), isTrue);
    expect(await settings.verifyPin('1234'), isTrue);
    expect(await settings.verifyPin('0000'), isFalse);

    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    expect(rows.any((r) => (r['value']! as String).contains('1234')), isFalse);
  });

  test('sound defaults on and persists off; section toggles persist', () async {
    expect(await settings.soundEnabled(), isTrue);
    await settings.setSoundEnabled(false);
    expect(await settings.soundEnabled(), isFalse);

    expect(await settings.isSectionEnabled(SectionIds.quran), isTrue);
    await settings.setSectionEnabled(SectionIds.quran, false);
    expect(await settings.isSectionEnabled(SectionIds.quran), isFalse);
    expect((await settings.sectionStates())[SectionIds.quran], isFalse);
    expect((await settings.sectionStates())[SectionIds.prayer], isTrue);
  });

  test('usage time accumulates per day and per child', () async {
    final fedaa = await byName('فداء');
    final nour = await byName('نور');
    await children.addUsage(fedaa.id, 15, '2026-11-12');
    await children.addUsage(fedaa.id, 15, '2026-11-12');
    await children.addUsage(fedaa.id, 15, '2026-11-13');
    await children.addUsage(nour.id, 15, '2026-11-12');

    expect(await children.usageSecondsOn(fedaa.id, '2026-11-12'), 30);
    expect(await children.usageSecondsOn(fedaa.id, '2026-11-13'), 15);
    expect(await children.totalSecondsUsed(fedaa.id), 45);
    expect(await children.totalSecondsUsed(nour.id), 15);
  });

  test('editing a child keeps progress and switches the age tier', () async {
    final nour = await byName('نور');
    await game.completeLesson(
      childId: nour.id,
      lessonId: 'learn_colors_basic',
      firstTryCorrect: 2,
      totalQuestions: 2,
      now: DateTime(2026, 11, 12, 10),
    );
    await children.update(nour.id, name: 'نور الصغيرة', age: 4);
    final updated = (await children.byId(nour.id))!;
    expect(updated.name, 'نور الصغيرة');
    expect(updated.age, 4);
    expect(updated.ageGroup, AgeGroup.early);
    expect(await game.completedLessonIds(nour.id), {'learn_colors_basic'});
  });
}
