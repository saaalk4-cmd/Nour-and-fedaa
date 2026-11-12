import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/content/lesson_progression.dart';

void main() {
  final all = ContentRepository.parseLessons(
    File(ContentRepository.learnAsset).readAsStringSync(),
  );
  final nour = all.where((l) => l.fitsAge(3)).toList();
  final fedaa = all.where((l) => l.fitsAge(5)).toList();

  test('3-year-old lessons are all open from the start (gentle)', () {
    for (final l in nour) {
      expect(LessonProgression.isUnlocked(l, nour, <String>{}), isTrue, reason: l.id);
    }
  });

  test('5-year-old harder lessons unlock after an easier one is done', () {
    final hard = fedaa.where((l) => l.difficulty == 2).toList();
    final easy = fedaa.where((l) => l.difficulty == 1).toList();
    expect(hard, isNotEmpty);
    expect(easy, isNotEmpty);

    for (final l in hard) {
      expect(LessonProgression.isUnlocked(l, fedaa, <String>{}), isFalse, reason: l.id);
    }
    final done = <String>{easy.first.id};
    for (final l in hard) {
      expect(LessonProgression.isUnlocked(l, fedaa, done), isTrue, reason: l.id);
    }
  });

  test('easy lessons are never locked', () {
    for (final l in fedaa.where((l) => l.difficulty == 1)) {
      expect(LessonProgression.isUnlocked(l, fedaa, <String>{}), isTrue);
    }
  });

  test('prerequisite points to an easier lesson', () {
    final hard = fedaa.firstWhere((l) => l.difficulty == 2);
    final pre = LessonProgression.prerequisite(hard, fedaa);
    expect(pre, isNotNull);
    expect(pre!.difficulty, 1);
  });

  test('next is the first open lesson not completed yet', () {
    final first = LessonProgression.next(nour, <String>{});
    expect(first, nour.first);
    final second = LessonProgression.next(nour, <String>{nour.first.id});
    expect(second, nour[1]);
    expect(LessonProgression.next(nour, nour.map((Lesson l) => l.id).toSet()), isNull);
  });
}
