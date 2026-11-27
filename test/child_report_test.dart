import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/repositories/badge_repository.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/data/repositories/usage_repository.dart';
import 'package:buraq/features/parent/child_report_screen.dart';
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
    await AppDatabase.instance.close();
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('buraq_test').path);
  });

  test('last 7 days: oldest first, today last, missing days are zero', () async {
    final u = UsageRepository();
    final today = DateTime(2026, 11, 27, 15);
    await u.add(1, 120, now: today);
    await u.add(1, 60, now: today.subtract(const Duration(days: 3)));
    final days = await u.lastDays(1, 7, now: today);
    expect(days.length, 7);
    expect(days.last.$1, DateTime(2026, 11, 27));
    expect(days.last.$2, 120);
    expect(days[3].$2, 60);
    expect(days.first.$2, 0);
  });

  test('report groups finished lessons by section and lists recent ones', () async {
    final id = await ChildRepository().add(ChildDraft(
        nickname: 'نجمة',
        avatar: 'star',
        birthYear: DateTime.now().year - 6,
        birthMonth: 1));
    final p = ProgressRepository();
    await p.complete(
        childId: id,
        lessonId: 'a_arabic_letters_1',
        stars: 3,
        now: DateTime(2026, 11, 25));
    await p.complete(
        childId: id,
        lessonId: 'a_akhlaq_truth',
        stars: 3,
        now: DateTime(2026, 11, 26));
    await BadgeRepository().evaluate(id);
    await UsageRepository().add(id, 300);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final r = await c.read(childReportProvider(id).future);
    expect(r.bySection, {'عربيتي': 1, 'أخلاقي': 1});
    expect(r.recent.first.$1, 'الصدق'); // الأحدث أولًا
    expect(r.weekMinutes, 5);
    expect(r.badges.map((b) => b.id), contains('first_lesson'));
  });

  testWidgets('report screen shows the week, sections and the retake button',
      (t) async {
    final child = Child(
        id: 1,
        nickname: 'نجمة',
        avatar: 'star',
        birthYear: DateTime.now().year - 6,
        birthMonth: 1);
    final today = DateTime.now();
    final report = ChildReport(
      child: child,
      days: [
        for (var i = 6; i >= 0; i--) (today.subtract(Duration(days: i)), i)
      ],
      bySection: const {'عربيتي': 2},
      recent: const [('حروفي ١', null)],
      badges: const [],
    );
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [childReportProvider(1).overrideWith((_) async => report)],
      child: const MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: ChildReportScreen(childId: 1)),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('٢١ دقيقة'), findsOneWidget);
    expect(find.text('عربيتي'), findsOneWidget);
    expect(find.text('حروفي ١'), findsOneWidget);
    expect(find.byKey(const Key('retake_check')), findsOneWidget);
  });
}
