import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/models/child_report.dart';
import 'package:nourfadaa/domain/gamification/milestones.dart';

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final byId = {for (final l in all) l.id: l};
  final curriculum = Curriculum.parse(File('assets/content/curriculum.json').readAsStringSync());
  final newWeek = RegExp(r'^w(1[3-9]|2\d)_');

  test('weeks 1-12 are the untouched baseline', () {
    const baseline = [17, 17, 15, 16, 17, 17, 17, 16, 17, 11, 11, 6];
    for (var i = 0; i < 12; i++) {
      final w = curriculum.weeks[i];
      expect(w.week, i + 1);
      expect(w.days.fold<int>(0, (n, d) => n + d.lessonIds.length), baseline[i], reason: 'week ${w.week}');
    }
  });

  test('weeks 13..24 exist, have 5 non-empty days of at most 5 adventures', () {
    expect(curriculum.weeks.map((w) => w.week), [for (var i = 1; i <= 24; i++) i]);
    for (final w in curriculum.weeks.skip(12)) {
      expect(w.days.length, 5, reason: 'week ${w.week}');
      for (final d in w.days) {
        expect(d.lessonIds, isNotEmpty, reason: 'w${w.week} d${d.day}');
        expect(d.lessonIds.length, lessThanOrEqualTo(5), reason: 'w${w.week} d${d.day}');
        expect(d.title, isNotEmpty);
      }
    }
  });

  test('new weeks work offline: no links, and no Quran text in educational lessons', () {
    final quranMarks = RegExp('[ٱۖ-ۭ]');
    for (final l in all.where((l) => newWeek.hasMatch(l.id))) {
      final text = [
        l.title,
        ...l.steps.map((s) => s.text),
        ...l.questions.expand((q) => [q.prompt, q.hint, ...q.options]),
      ].join(' ');
      expect(text.contains('http'), isFalse, reason: l.id);
      expect(quranMarks.hasMatch(text), isFalse, reason: '${l.id} must not contain Quran text');
      expect(l.source.type, 'educational', reason: l.id);
    }
  });

  test('religious lessons used in weeks 13-24 carry book, number and grade', () {
    final w = curriculum.weeks.skip(12).expand((w) => w.days).expand((d) => d.lessonIds);
    final religious = w.where((id) => !newWeek.hasMatch(id)).toList();
    expect(religious, containsAll(['hadith_wudu_prayer_lesson', 'hadith_remove_harm_lesson']));
    expect(byId['hadith_wudu_prayer_lesson']!.source.reference, allOf(contains('164'), contains('صحيح')));
    expect(byId['hadith_remove_harm_lesson']!.source.reference, allOf(contains('2989'), contains('صحيح')));
    for (final id in religious) {
      expect(byId[id]!.source.type, isNot('educational'), reason: id);
    }
  });

  test('listening activities only reference recorded surahs and carry no text of the ayah', () {
    const surahs = {112, 113, 114, 108, 103, 110, 106};
    var count = 0;
    for (final l in all.where((l) => newWeek.hasMatch(l.id))) {
      for (final r in [
        ...l.steps.map((s) => s.recite),
        ...l.questions.map((q) => q.recite),
      ].whereType<Recitation>()) {
        count++;
        expect(surahs, contains(r.surah), reason: l.id);
        expect(r.ayah, 1, reason: l.id);
      }
    }
    expect(count, greaterThan(20));
  });

  test('match and order questions are well formed and are not used for age 3-4 views', () {
    var matches = 0;
    var orders = 0;
    for (final l in all.where((l) => newWeek.hasMatch(l.id))) {
      for (final q in l.questions) {
        if (q.isMatch) {
          matches++;
          expect(q.options.length, inInclusiveRange(2, 4), reason: l.id);
          expect(q.matchRight.toSet().length, q.matchRight.length, reason: l.id);
        }
        if (q.isOrder) {
          orders++;
          expect(q.displayOptions, isNot(equals(q.options)), reason: l.id);
        }
      }
      expect(l.toddlerQuestions().any((q) => q.isMatch || q.isOrder), isFalse, reason: l.id);
    }
    expect(matches, greaterThan(5));
    expect(orders, greaterThan(5));
  });

  test('a child walks week 1 -> 24 and then graduates (plan finishes)', () {
    final done = <String>{};
    var days = 0;
    while (true) {
      final plan = curriculum.planFor(childAge: 5, allLessons: all, completed: done);
      if (plan.finishedAll) break;
      expect(plan.adventures, isNotEmpty);
      done.addAll(plan.adventures.map((l) => l.id));
      days++;
      expect(days, lessThanOrEqualTo(120));
    }
    expect(days, 120);
    final last = curriculum.weeks.last.days.last.lessonIds;
    expect(last, contains('w24_graduation'));
  });

  group('milestones', () {
    Set<String> finishWeeks(int upTo) => {
          for (final w in curriculum.weeks.where((w) => w.week <= upTo))
            ...Milestones.weekLessons(w, 5, byId),
        };

    test('finishing week 1 gives a week reward only once', () {
      final done = finishWeeks(1);
      final first = Milestones.newlyReached(
        curriculum: curriculum, childAge: 5, allLessons: all, completed: done, alreadyGranted: {});
      expect(first.map((m) => m.id), ['ms_week_1']);
      final again = Milestones.newlyReached(
        curriculum: curriculum, childAge: 5, allLessons: all, completed: done, alreadyGranted: {'ms_week_1'});
      expect(again, isEmpty);
    });

    test('every 4 weeks gives a badge, week 24 gives graduation', () {
      final four = Milestones.newlyReached(
        curriculum: curriculum, childAge: 5, allLessons: all, completed: finishWeeks(4), alreadyGranted: {});
      expect(four.map((m) => m.id), containsAll(['ms_week_4', 'month_1']));
      final everything = Milestones.newlyReached(
        curriculum: curriculum, childAge: 5, allLessons: all, completed: finishWeeks(24), alreadyGranted: {});
      final ids = everything.map((m) => m.id).toSet();
      expect(ids, containsAll(['month_1', 'month_2', 'month_3', 'month_4', 'month_5', 'graduate_24']));
      expect(everything.where((m) => m.graduation).length, 1);
      expect(everything.every((m) => m.stars > 0 && m.xp > 0), isTrue);
    });

    test('an unfinished week gives nothing; no reward for a week without lessons for her age', () {
      final partial = finishWeeks(3)..remove(curriculum.weeks[2].days.last.lessonIds.first);
      final r = Milestones.newlyReached(
        curriculum: curriculum, childAge: 5, allLessons: all, completed: partial, alreadyGranted: {'ms_week_1', 'ms_week_2'});
      expect(r, isEmpty);
      final none = Milestones.newlyReached(
        curriculum: curriculum, childAge: 3, allLessons: all, completed: {}, alreadyGranted: {});
      expect(none, isEmpty);
    });
  });

  test('smart review picks the weakest finished educational lesson, never a perfect one', () {
    final a = byId['w13_numbers']!;
    final b = byId['w13_add']!;
    final entries = [
      ProgressEntry(lessonId: a.id, score: a.questions.length, completedAt: DateTime(2026, 1, 1)),
      ProgressEntry(lessonId: b.id, score: 0, completedAt: DateTime(2026, 1, 2)),
    ];
    final pick = ReviewPicker.pick(entries: entries, byId: byId, childAge: 5);
    expect(pick?.id, b.id);
    expect(ReviewPicker.pick(entries: entries, byId: byId, childAge: 5, exclude: {b.id}), isNull);
    expect(ReviewPicker.pick(entries: [entries.first], byId: byId, childAge: 5), isNull);
  });
}
