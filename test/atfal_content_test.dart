import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<LessonStep> _chooses(Lesson l) =>
    l.steps.where((s) => s.type == StepType.choose);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = LessonRepository();
  moreContentTests();
  olderAkhlaqTests();

  test('arabic letters: all 28 letters once, each answer word starts with its letter',
      () async {
    final lessons = await repo.bySection('arabic', AgeBand.atfal);
    final letterLessons =
        lessons.where((l) => l.id.startsWith('a_arabic_letters_')).toList();
    expect(letterLessons.length, 7);
    final seen = <String>[];
    for (final l in letterLessons) {
      expect(l.sourceType, 'educational');
      for (final s in _chooses(l)) {
        final letter = s.prompt!.replaceAll('ـ', '');
        seen.add(letter);
        expect(s.optionLabels[s.answer].startsWith(letter), isTrue,
            reason: '${l.id}: ${s.optionLabels[s.answer]} / $letter');
        // المشتتات لا تبدأ بالحرف نفسه
        for (var i = 0; i < s.optionLabels.length; i++) {
          if (i != s.answer) {
            expect(s.optionLabels[i].startsWith(letter), isFalse);
          }
        }
      }
    }
    expect(seen.length, 28);
    expect(seen.toSet().length, 28);
  });

  test('salah: five prayers and the fard rak`ah counts are correct', () async {
    final lessons = await repo.bySection('prayer', AgeBand.atfal);
    expect(lessons.map((l) => l.id), ['a_salah_five', 'a_salah_rakat']);
    String correct(LessonStep s) => s.options[s.answer];

    final five = _chooses(lessons[0]).toList();
    expect(correct(five[0]), '٥');
    expect(five.skip(1).map(correct), ['الفجر', 'العصر', 'المغرب', 'العشاء']);

    final rakat = _chooses(lessons[1]).map(correct).toList();
    // الفجر، الظهر، العصر، المغرب، العشاء
    expect(rakat, ['٢', '٤', '٤', '٣', '٤']);
  });

  test('answer positions vary so the child cannot always tap the same spot',
      () async {
    final lessons = [
      ...await repo.bySection('arabic', AgeBand.atfal),
      ...await repo.bySection('prayer', AgeBand.atfal),
    ];
    final positions =
        lessons.expand(_chooses).map((s) => s.answer).toSet();
    expect(positions.length, greaterThan(1));
  });
}

void moreContentTests() {
  final repo = LessonRepository();

  test('first/last letter questions: the right option is really the first/last letter',
      () async {
    final lessons = (await repo.bySection('arabic', AgeBand.atfal))
        .where((l) => l.id.startsWith('a_arabic_words_'));
    expect(lessons.length, 4);
    for (final l in lessons) {
      for (final s in _chooses(l)) {
        final word = s.prompt!;
        final isFirst = s.question!.contains('الأول');
        final expected = isFirst ? word[0] : word[word.length - 1];
        expect(s.options[s.answer], expected, reason: '${l.id}: $word');
        expect(s.options.toSet().length, s.options.length);
      }
    }
  });

  test('akhlaq for 5-7 is general educational content', () async {
    final lessons = await repo.bySection('akhlaq', AgeBand.atfal);
    expect(lessons.length, 4);
    for (final l in lessons) {
      expect(l.sourceType, 'educational');
      expect(_chooses(l).length, greaterThanOrEqualTo(3));
    }
  });

  test('older bands now have Arabic lessons', () async {
    for (final b in [AgeBand.nashia, AgeBand.murahiqun]) {
      final ls = await repo.bySection('arabic', b);
      expect(ls.where((l) => l.level == 1).length, 3, reason: b.name);
      expect(ls.where((l) => l.level == 2).length, 3, reason: b.name);
    }
  });
}

void olderAkhlaqTests() {
  test('akhlaq for 8-11 and 12-14: general educational scenarios', () async {
    final repo = LessonRepository();
    for (final band in [AgeBand.nashia, AgeBand.murahiqun]) {
      final lessons = await repo.bySection('akhlaq', band);
      expect(lessons.length, 3, reason: band.name);
      for (final l in lessons) {
        expect(l.sourceType, 'educational');
        expect(_chooses(l).length, greaterThanOrEqualTo(3));
      }
    }
  });
}
