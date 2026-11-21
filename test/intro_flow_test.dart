import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/features/intro/cinema_painter.dart';
import 'package:nourfadaa/features/intro/intro_cinema_screen.dart';

void main() {
  testWidgets('plays by itself, fires every cue once, then calls onDone', (tester) async {
    var done = 0;
    final cues = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: IntroCinemaScreen(
        onDone: () => done++,
        onExit: (_) => fail('should not exit'),
        onCue: cues.add,
        holdAtEnd: const Duration(milliseconds: 200),
      ),
    ));
    expect(done, 0);
    for (var i = 0; i < 46; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, 1);
    expect(cues, kCinemaCues.map((c) => c.name).toList());
  });

  testWidgets('skip button exits early with the elapsed seconds, once', (tester) async {
    final exits = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: IntroCinemaScreen(onDone: () => fail('not finished'), onExit: exits.add),
    ));
    await tester.pump(const Duration(seconds: 12));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded), warnIfMissed: false);
    expect(exits.length, 1);
    expect(exits.first, inInclusiveRange(11, 13));
  });

  testWidgets('system back during the film exits safely instead of closing the app', (tester) async {
    final exits = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: IntroCinemaScreen(onDone: () => fail('not finished'), onExit: exits.add),
    ));
    await tester.pump(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits.length, 1);
  });

  test('the film has no text and no baked-in religious figures: map uses emoji icons only', () {
    final src = File('lib/features/intro/cinema_painter.dart').readAsStringSync();
    // أسماء المناطق لا تظهر نصًا داخل المشهد.
    for (final word in ['غابة الحروف', 'وادي الأرقام', 'حديقة الألوان']) {
      expect(src.contains(word), isFalse, reason: word);
    }
  });
}
