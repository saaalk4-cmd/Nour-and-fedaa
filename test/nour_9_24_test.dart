import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';

/// مسار نور (3 سنوات) للأسابيع 9–24: صور وصوت ولمس، بلا قراءة، ومنهج فداء كما هو.
void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets) ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final byId = {for (final l in all) l.id: l};
  final curriculum = Curriculum.parse(File('assets/content/curriculum.json').readAsStringSync());
  final arabic = RegExp(r'[؀-ۿ]');
  final nourWeeks = curriculum.weeks.where((w) => w.week >= 9).toList();

  test('every day of weeks 9-24 has an early (picture) track of 1-3 lessons', () {
    expect(nourWeeks.length, 16);
    for (final w in nourWeeks) {
      for (final d in w.days) {
        expect(d.earlyLessonIds.length, inInclusiveRange(1, 3), reason: 'w${w.week} d${d.day}');
        for (final id in d.earlyLessonIds) {
          expect(byId[id], isNotNull, reason: 'missing $id');
          expect(byId[id]!.fitsAge(3), isTrue, reason: id);
        }
      }
    }
  });

  test("Nour's lessons are voice-first: spoken cards, picture-only options, short cards", () {
    final mine = all.where((l) => RegExp(r'^w(\d+)e_').hasMatch(l.id) && int.parse(RegExp(r'^w(\d+)e_').firstMatch(l.id)!.group(1)!) >= 9);
    expect(mine.length, greaterThan(90));
    for (final l in mine) {
      expect(l.source.type, 'educational', reason: l.id);
      expect(l.maxAge, 4, reason: l.id);
      for (final s in l.steps) {
        expect((s.say ?? '').isNotEmpty, isTrue, reason: '${l.id} step not spoken');
        expect(s.text.split(RegExp(r'\s+')).length, lessThanOrEqualTo(3), reason: '${l.id}: ${s.text}');
      }
      for (final q in l.questions) {
        expect((q.say ?? '').isNotEmpty, isTrue, reason: '${l.id} question not spoken');
        expect(q.options.length, inInclusiveRange(2, 3), reason: l.id);
        expect(q.options.toSet().length, q.options.length, reason: '${l.id} duplicate options');
        for (final o in q.options) {
          expect(arabic.hasMatch(o), isFalse, reason: '${l.id}: "$o" needs reading');
        }
      }
    }
  });

  test('religious anchors are existing verified lessons only (no new religious text)', () {
    for (final w in nourWeeks) {
      for (final d in w.days) {
        for (final id in d.earlyLessonIds) {
          if (RegExp(r'^w\d+e_').hasMatch(id)) continue;
          final l = byId[id]!;
          expect(id.startsWith('hadith_') || id.startsWith('prophet_') || id.startsWith('quran_surah_'), isTrue, reason: id);
          expect(l.source.type == 'educational', isFalse, reason: id);
          expect(l.toddler != null || l.surahNumber != null, isTrue, reason: '$id needs a toddler view');
        }
      }
    }
  });

  test('Nour plan walks weeks 1-24 to the end with something to do each day', () {
    final done = <String>{};
    var days = 0;
    for (var i = 0; i < 140; i++) {
      final plan = curriculum.planFor(childAge: 3, allLessons: all, completed: done);
      if (plan.finishedAll) break;
      expect(plan.adventures, isNotEmpty);
      days++;
      done.addAll(plan.adventures.map((l) => l.id));
    }
    expect(curriculum.planFor(childAge: 3, allLessons: all, completed: done).finishedAll, isTrue);
    expect(days, greaterThan(100));
  });

  test("Fedaa's curriculum is untouched by Nour's track", () {
    const baseline = [17, 17, 15, 16, 17, 17, 17, 16, 17, 11, 11, 6];
    for (var i = 0; i < 12; i++) {
      final w = curriculum.weeks[i];
      expect(w.days.fold<int>(0, (n, d) => n + d.lessonIds.length), baseline[i], reason: 'week ${w.week}');
    }
    for (final w in nourWeeks) {
      for (final d in w.days) {
        expect(d.lessonIds.any((id) => RegExp(r'^w\d+e_').hasMatch(id)), isFalse);
      }
    }
  });

  test('week 9-24 early lessons keep the kind wording (no failure words)', () {
    const banned = ['فشل', 'خطأ', 'خسر', 'سيئة'];
    for (final l in all.where((l) => RegExp(r'^w(9|1\d|2[0-4])e_').hasMatch(l.id))) {
      final t = [l.title, ...l.steps.map((s) => s.text), ...l.questions.expand((q) => [q.hint, q.praise ?? ''])].join(' ');
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: l.id);
      }
    }
  });
}
