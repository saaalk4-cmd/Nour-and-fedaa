import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/features/lessons/break_reminder.dart';

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final forFedaa = all.where((l) => l.fitsAge(5)).toList();

  test('quoted ayah/hadith text is never machine-spoken', () {
    for (final l in forFedaa) {
      if (l.canSpeak) continue;
      // الخطوة الأولى في الدروس الدينية هي النص المنقول نفسه.
      final quote = l.steps.first;
      expect(l.spokenText(quote.text, say: quote.say), isNull,
          reason: '${l.id}: the quoted text must not be spoken');
      for (final q in l.questions) {
        final spoken = l.spokenText(q.prompt, say: q.say) ?? '';
        expect(spoken.contains(quote.text), isFalse,
            reason: '${l.id}: question speech contains the quote');
      }
    }
  });

  test('explicit say fields in religious lessons are plain (unvowelled) speech', () {
    final tashkeel = RegExp('[ً-ْٰ]');
    for (final l in forFedaa) {
      if (l.canSpeak) continue;
      for (final s in l.steps) {
        if (s.say != null) {
          expect(tashkeel.allMatches(s.say!).length, lessThan(3), reason: l.id);
        }
      }
    }
  });

  test('every religious lesson has at least one spoken step (the simple meaning)', () {
    for (final l in forFedaa) {
      if (l.canSpeak || l.surahNumber != null) continue;
      final spoken = l.steps.where((s) => l.spokenText(s.text, say: s.say, step: true) != null);
      expect(spoken, isNotEmpty, reason: '${l.id} has nothing for the child to hear');
    }
  });

  test('order questions have 2-5 unique items and appear only in educational lessons', () {
    var count = 0;
    for (final l in all) {
      for (final q in l.questions.where((q) => q.isOrder)) {
        count++;
        expect(l.source.type, 'educational', reason: l.id);
        expect(q.options.length, inInclusiveRange(2, 5), reason: l.id);
        expect(q.options.toSet().length, q.options.length, reason: l.id);
        expect(q.displayOptions, isNot(equals(q.options)), reason: '${l.id} would show the answer already ordered');
      }
    }
    expect(count, greaterThan(0));
  });

  test('break reminder is due only after the interval', () {
    final t = DateTime(2026, 1, 1, 10);
    expect(BreakReminder.due(t.add(const Duration(minutes: 14)), anchor: t), isFalse);
    expect(BreakReminder.due(t.add(const Duration(minutes: 15)), anchor: t), isTrue);
  });
}
