import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/design/kit.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/features/home/who_learns_screen.dart';
import 'package:nourfadaa/features/world/world_screen.dart';

Lesson _lesson(String id, String title) => Lesson(
      id: id,
      title: title,
      emoji: '🔤',
      category: 'learn',
      minAge: 3,
      maxAge: 6,
      difficulty: 1,
      steps: const [],
      questions: const [],
      source: const ContentSource(type: 'educational', reference: 'test'),
    );

Widget _host(Size size, Widget child) => MediaQuery(
      data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child])),
      ),
    );

void main() {
  final week = PathWeek(
    week: const CurriculumWeek(week: 1, title: 'أسبوع', days: []),
    finishedAll: false,
    days: [
      PathDay(day: 1, title: 'يوم', nodes: [
        PathNode(_lesson('a', 'حروفي الأولى'), PathState.done),
        PathNode(_lesson('b', 'مقاطع حرف الباء مع كلمات جميلة وطويلة'), PathState.current),
        PathNode(_lesson('c', 'أقرأ كلمات'), PathState.locked),
      ]),
      PathDay(day: 2, title: 'يوم', nodes: [PathNode(_lesson('d', 'نعدّ معًا'), PathState.locked)]),
    ],
  );

  for (final size in const [Size(320, 640), Size(411, 891)]) {
    testWidgets('mission card fits and starts the current lesson (${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      String? started;
      await tester.pumpWidget(_host(
        size,
        MissionCard(
          path: week,
          child: const Child(id: 1, name: 'فداء', age: 5),
          onStart: (l) => started = l.id,
          onGift: (_) {},
          onDone: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('ابدأ الآن'), findsOneWidget);
      await tester.tap(find.text('ابدأ الآن'));
      expect(started, 'b');
    });

    testWidgets('wood signs and kid pills fit without overflow (${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var taps = 0;
      await tester.pumpWidget(_host(
        size,
        Column(
          children: [
            WoodSign(icon: const Text('🕌'), title: 'الدين والأذكار', subtitle: 'قرآن وصلاة وأنبياء', onTap: () => taps++),
            const SizedBox(height: 12),
            ChildCard(child: const Child(id: 2, name: 'نور', age: 3), onTap: () => taps++),
            const SizedBox(height: 12),
            const LogoSign(title: 'نُور وفداء', subtitle: 'عالم من التعلم والمغامرة'),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('الدين والأذكار'));
      expect(taps, 1);
    });
  }

  test('finished week shows the explorer medal instead of a lesson', () {
    const done = PathWeek(week: null, days: [], finishedAll: true);
    expect(done.current, isNull);
  });

  test('age labels read naturally in Arabic', () {
    expect(ageLabel(3), '3 سنوات');
    expect(ageLabel(5), '5 سنوات');
    expect(ageLabel(2), 'سنتان');
  });

  test('religion signpost groups only the religious sections', () {
    expect(deenSectionIds, isNot(contains('learn')));
    expect(deenSectionIds, isNot(contains('akhlaq')));
    expect(deenSectionIds.length, 6);
  });
}
