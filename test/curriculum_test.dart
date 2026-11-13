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
        for (final id in [...d.lessonIds, ...d.earlyLessonIds]) {
          expect(byId.containsKey(id), isTrue, reason: 'missing $id');
        }
        used.addAll(d.lessonIds);
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

  test('non-reader track: spoken prompts, picture options, and only age 3-4 lessons', () {
    final byId = {for (final l in all) l.id: l};
    final arabic = RegExp(r'[\u0600-\u06FF]');
    for (final d in curriculum.weeks.first.days) {
      expect(d.earlyLessonIds, isNotEmpty, reason: 'day ${d.day}');
      for (final id in d.earlyLessonIds) {
        final l = byId[id]!;
        expect(l.fitsAge(3), isTrue, reason: id);
        if (!id.startsWith('w1e_')) continue; // السور تُسمع بالتلاوة
        for (final st in l.steps) {
          expect(st.say, isNotEmpty, reason: '$id step has nothing to speak');
        }
        for (final q in l.questions) {
          expect(q.say, isNotEmpty, reason: '$id question has nothing to speak');
          if (!l.allowSpeech) {
            // الخيارات صور فقط: الطفلة لا تقرأ.
            for (final o in q.options) {
              expect(arabic.hasMatch(o), isFalse, reason: '$id option "$o" needs reading');
            }
          }
        }
      }
    }
  });

  test('religious lessons are never spoken by the machine voice unless explicitly allowed', () {
    for (final l in all) {
      if (l.source.type != 'educational' && !l.allowSpeech) {
        expect(l.canSpeak, isFalse, reason: l.id);
      }
    }
    final bism = all.firstWhere((l) => l.id == 'w1e_bismillah');
    expect(bism.source.type, 'sahih_sunnah');
    expect(bism.source.reference, contains('5376'));
  });

  test('younger child follows the early track through all 5 days', () {
    final done = <String>{};
    for (var day = 1; day <= 5; day++) {
      final plan = curriculum.planFor(childAge: 3, allLessons: all, completed: done);
      expect(plan.day!.day, day);
      expect(plan.adventures.map((l) => l.id), plan.day!.earlyLessonIds);
      done.addAll(plan.adventures.map((l) => l.id));
    }
    expect(curriculum.planFor(childAge: 3, allLessons: all, completed: done).finishedAll, isTrue);
  });
}

const curriculumAsset = 'assets/content/curriculum.json';
