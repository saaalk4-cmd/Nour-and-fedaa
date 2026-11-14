import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';

void main() {
  final raw = File(ContentRepository.learnAsset).readAsStringSync();
  final lessons = ContentRepository.parseLessons(raw);

  test('every lesson has a valid source, steps and questions', () {
    expect(lessons, isNotEmpty);
    for (final l in lessons) {
      expect(ContentSource.allowedTypes, contains(l.source.type), reason: l.id);
      expect(l.source.reference.trim(), isNotEmpty, reason: l.id);
      expect(l.steps, isNotEmpty, reason: l.id);
      expect(l.questions, isNotEmpty, reason: l.id);
    }
  });

  test('lesson ids are unique', () {
    final ids = lessons.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('both age groups have lessons (3-year-old and 5-year-old)', () {
    expect(lessons.where((l) => l.fitsAge(3)).length, greaterThanOrEqualTo(3));
    expect(lessons.where((l) => l.fitsAge(5)).length, greaterThanOrEqualTo(3));
  });

  test('content for 3 and 5 year olds is different', () {
    final nour = lessons.where((l) => l.fitsAge(3)).map((l) => l.id).toSet();
    final fedaa = lessons.where((l) => l.fitsAge(5)).map((l) => l.id).toSet();
    expect(nour.intersection(fedaa), isEmpty);
  });

  test('a lesson without a source is rejected', () {
    const bad = '{"lessons":[{"id":"x","title":"t","emoji":"e","category":"learn",'
        '"minAge":3,"maxAge":4,"difficulty":1,'
        '"steps":[{"emoji":"a","text":"b"}],"questions":[]}]}';
    expect(() => ContentRepository.parseLessons(bad), throwsFormatException);
  });
}
