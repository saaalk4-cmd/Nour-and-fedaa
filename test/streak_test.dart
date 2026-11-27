import 'package:buraq/core/widgets/phone_width.dart';
import 'package:buraq/domain/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 27, 18);
  DateTime d(int day, [int h = 10]) => DateTime(2026, 11, day, h);

  test('streak counts consecutive days ending today', () {
    expect(streakDays([d(27), d(26), d(25), d(23)], now), 3);
  });

  test('no lesson yet today keeps yesterday\'s streak alive', () {
    expect(streakDays([d(26), d(25)], now), 2);
  });

  test('a gap of two days resets the streak', () {
    expect(streakDays([d(24), d(23)], now), 0);
    expect(streakDays([], now), 0);
  });

  test('several lessons on one day count once for the streak, all for today',
      () {
    final c = [d(27, 9), d(27, 15), d(26)];
    expect(streakDays(c, now), 2);
    expect(lessonsOn(c, now), 2);
  });

  testWidgets('tablet: content is centered at phone width', (t) async {
    t.view.physicalSize = const Size(1600, 2400);
    t.view.devicePixelRatio = 2.0; // 800x1200 منطقي
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(
      home: PhoneWidth(child: SizedBox.expand(key: Key('content'))),
    ));
    expect(t.getSize(find.byKey(const Key('content'))).width, 600);
  });

  testWidgets('phone: content uses the full width', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(
      home: PhoneWidth(child: SizedBox.expand(key: Key('content'))),
    ));
    expect(t.getSize(find.byKey(const Key('content'))).width,
        closeTo(1080 / 2.75, 0.5));
  });
}
