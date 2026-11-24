import 'dart:io';
import 'package:buraq/core/widgets/usage_tracker.dart';
import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/data/repositories/usage_repository.dart';
import 'package:flutter/material.dart';
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
    await databaseFactory
        .setDatabasesPath(Directory.systemTemp.createTempSync('buraq_test').path);
    await AppDatabase.instance.close();
  });

  test('daily limit defaults to 30 and can be changed, 0 = unlimited', () async {
    final s = SettingsRepository();
    expect(await s.dailyLimitMinutes(), 30);
    await s.setDailyLimitMinutes(0);
    expect(await s.dailyLimitMinutes(), 0);
  });

  test('usage accumulates per day', () async {
    final u = UsageRepository();
    final d = DateTime(2026, 5, 1);
    await u.add(1, 15, now: d);
    await u.add(1, 15, now: d);
    await u.add(1, 15, now: d.add(const Duration(days: 1)));
    expect(await u.secondsOn(1, d), 30);
    expect(await ChildRepository().totalSecondsUsed(1), 45);
  });

  test('deleting a child removes related data', () async {
    final repo = ChildRepository();
    final id = await repo.add(const ChildDraft(
        nickname: 'ن', avatar: 'star', birthYear: 2018, birthMonth: 1));
    await UsageRepository().add(id, 60);
    await repo.delete(id);
    expect(await repo.byId(id), isNull);
    expect(await repo.totalSecondsUsed(id), 0);
  });

  test('limitReached only when limit > 0 and usage >= limit', () async {
    final c = ProviderContainer(overrides: [
      dailyLimitProvider.overrideWith((_) async => 1),
    ]);
    addTearDown(c.dispose);
    await c.read(dailyLimitProvider.future);
    expect(c.read(limitReachedProvider), isFalse);
    c.read(todaySecondsProvider.notifier).state = 60;
    expect(c.read(limitReachedProvider), isTrue);
  });

  testWidgets('tracker records time for the selected child, not when paused',
      (tester) async {
    await tester.runAsync(() async {
      final id = await ChildRepository().add(const ChildDraft(
          nickname: 'ن', avatar: 'star', birthYear: 2018, birthMonth: 1));
      final container = ProviderContainer();
      container.read(selectedChildIdProvider.notifier).state = id;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: UsageTracker(
              tick: Duration(milliseconds: 50),
              secondsPerTick: 1,
              child: SizedBox()),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final counted = await UsageRepository().secondsOn(id, DateTime.now());
      expect(counted, greaterThan(0));
      container.read(usagePausedProvider.notifier).state = true;
      final before = await UsageRepository().secondsOn(id, DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(await UsageRepository().secondsOn(id, DateTime.now()), before);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
