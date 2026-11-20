import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/quran.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/features/quran/hifz.dart';
import 'package:nourfadaa/features/quran/hifz_screens.dart';
import 'package:nourfadaa/features/home/section_screen.dart';
import 'package:nourfadaa/features/quran/quran_screen.dart';

void main() {
  final q = QuranRepository.parse(File('assets/content/quran_surahs.json').readAsStringSync());

  Future<void> pump(WidgetTester tester, Child c, Widget home, {Size size = const Size(320, 640)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        selectedChildProvider.overrideWith((_) async => c),
        quranContentProvider.overrideWith((_) async => q),
        hifzProvider.overrideWith((ref, c) async => HifzProgress.initialFor(name: c.name, age: c.age)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (ctx, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: home,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final size in const [Size(320, 640), Size(411, 891)]) {
    testWidgets('Fedaa sees today\'s wird and the three juz (${size.width.toInt()}px)', (tester) async {
      await pump(tester, const Child(id: 1, name: 'فداء', age: 5), const QuranHomeScreen(), size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('ورد اليوم'), findsWidgets);
      expect(find.textContaining('سورة المجادلة: من ١ لـ ٣'), findsOneWidget);
      expect(find.text('جزء قد سمع'), findsOneWidget);
      expect(find.text('رتّبي الآيات'), findsWidgets, reason: 'review games for memorized surahs');
      await tester.scrollUntilVisible(find.text('سورة الناس'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('سورة الناس'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('جزء قد سمع'), -200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('جزء قد سمع'));
      await tester.pump();
      expect(find.text('سورة المجادلة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Nour sees only juz Amma and Tabarak, no wird', (tester) async {
    await pump(tester, const Child(id: 2, name: 'نور', age: 3), const QuranHomeScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('جزء قد سمع'), findsNothing);
    expect(find.text('جزء تبارك'), findsOneWidget);
    expect(find.textContaining('سورة المجادلة'), findsNothing);
  });

  testWidgets('the memorization screen fits on a small phone', (tester) async {
    const c = Child(id: 1, name: 'فداء', age: 5);
    await pump(tester, c, SurahHifzScreen(child: c, content: q, parts: const [AyahRange(58, 1, 3)], purpose: HifzPurpose.newPart));
    expect(tester.takeException(), isNull);
    expect(find.text('سمّعي 🎤'), findsOneWidget);
    expect(find.text('اسمعي ورددي 🎧'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final c in const [Child(id: 1, name: 'فداء', age: 5), Child(id: 2, name: 'نور', age: 3)]) {
    testWidgets('the Quran section opens the juz and wird screen for ${c.name}', (tester) async {
      await pump(tester, c, const SectionScreen(sectionId: 'quran'));
      expect(find.byType(QuranHomeScreen), findsOneWidget);
      expect(find.text('جزء عمّ'), findsOneWidget);
    });
  }
}
