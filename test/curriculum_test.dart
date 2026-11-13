import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final curriculum = Curriculum.parse(File(curriculumAsset).readAsStringSync());

  test('lesson ids are unique across all content files', () {
    final ids = all.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every lesson in the curriculum exists and is used only once', () {
    final byId = {for (final l in all) l.id: l};
    final used = <String>[];
    for (final w in curriculum.weeks) {
      for (final d in w.days) {
        for (final id in d.lessonIds) {
          expect(byId.containsKey(id), isTrue, reason: 'missing $id');
          used.add(id);
        }
      }
    }
    expect(used.toSet().length, used.length, reason: 'a lesson appears twice');
  });

  test('week 1 days hold 2-5 adventures and every one has goal, learned and a hint', () {
    final byId = {for (final l in all) l.id: l};
    final week1 = curriculum.weeks.first;
    expect(week1.days.length, 5);
    for (final d in week1.days) {
      expect(d.lessonIds.length, inInclusiveRange(2, 5), reason: 'day ${d.day}');
    }
    for (final l in all.where((l) => l.id.startsWith('w1_'))) {
      expect(l.objective, isNotEmpty, reason: l.id);
      expect(l.learned, isNotEmpty, reason: l.id);
      expect(l.source.type, 'educational', reason: l.id);
      for (final q in l.questions) {
        expect(q.hint, isNotEmpty, reason: l.id);
      }
      expect(byId[l.id], isNotNull);
    }
  });

  test('week 1 never uses failure wording', () {
    const banned = ['فشل', 'خطأ', 'خسر', 'سيئة'];
    for (final l in all.where((l) => l.id.startsWith('w1_'))) {
      final texts = [
        l.title,
        ...l.steps.map((s) => s.text),
        ...l.questions.expand((q) => [q.prompt, q.hint, q.praise ?? '', ...q.options]),
      ].join(' ');
      for (final b in banned) {
        expect(texts.contains(b), isFalse, reason: '${l.id} contains $b');
      }
    }
  });

  test('plan follows progress: day 1 → day 2 → ... → finished', () {
    final done = <String>{};
    var plan = curriculum.planFor(childAge: 5, allLessons: all, completed: done);
    expect(plan.day!.day, 1);
    expect(plan.adventures.length, 4);
    for (var day = 1; day <= 5; day++) {
      plan = curriculum.planFor(childAge: 5, allLessons: all, completed: done);
      expect(plan.day!.day, day);
      done.addAll(plan.adventures.map((l) => l.id));
    }
    plan = curriculum.planFor(childAge: 5, allLessons: all, completed: done);
    expect(plan.finishedAll, isTrue);
  });

  test('younger child only sees age-appropriate adventures and never an empty day', () {
    final plan = curriculum.planFor(childAge: 3, allLessons: all, completed: <String>{});
    expect(plan.adventures, isNotEmpty);
    for (final l in plan.adventures) {
      expect(l.fitsAge(3), isTrue, reason: l.id);
    }
  });
}

const curriculumAsset = 'assets/content/curriculum.json';
