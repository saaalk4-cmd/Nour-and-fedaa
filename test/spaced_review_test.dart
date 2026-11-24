import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/data/repositories/review_repository.dart';
import 'package:buraq/domain/spaced_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('schedule', () {
    test('box rises on success up to the last, resets on forgetting', () {
      expect(nextBox(0, remembered: true), 1);
      expect(nextBox(maxReviewBox, remembered: true), maxReviewBox);
      expect(nextBox(3, remembered: false), 0);
    });

    test('intervals grow and due date counts from today', () {
      expect(reviewIntervalsDays, [1, 3, 7, 14, 30]);
      final today = DateTime(2026, 5, 10, 18, 30);
      expect(dueDateFor(0, today), DateTime(2026, 5, 11));
      expect(dueDateFor(2, today), DateTime(2026, 5, 17));
    });
  });

  group('storage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      await databaseFactory.setDatabasesPath(
          Directory.systemTemp.createTempSync('buraq_test').path);
      await AppDatabase.instance.close();
    });

    test('completing a lesson schedules review for tomorrow, not today', () async {
      final day = DateTime(2026, 5, 10, 9);
      await ProgressRepository()
          .complete(childId: 1, lessonId: 'a', stars: 2, now: day);
      final r = ReviewRepository();
      expect(await r.due(1, now: day), isEmpty);
      expect(await r.due(1, now: DateTime(2026, 5, 11)), ['a']);
    });

    test('review moves the due date out; forgetting brings it back', () async {
      final r = ReviewRepository();
      final d0 = DateTime(2026, 5, 10);
      await ProgressRepository()
          .complete(childId: 1, lessonId: 'a', stars: 2, now: d0);
      final d1 = DateTime(2026, 5, 11);
      await r.recordReview(1, 'a', remembered: true, now: d1); // box 1 -> +3
      expect(await r.due(1, now: DateTime(2026, 5, 13)), isEmpty);
      expect(await r.due(1, now: DateTime(2026, 5, 14)), ['a']);
      await r.recordReview(1, 'a', remembered: false, now: DateTime(2026, 5, 14));
      expect(await r.due(1, now: DateTime(2026, 5, 15)), ['a']); // box 0 -> +1
    });

    test('repeating a lesson does not reset its review schedule', () async {
      final r = ReviewRepository();
      final d0 = DateTime(2026, 5, 10);
      await ProgressRepository()
          .complete(childId: 1, lessonId: 'a', stars: 2, now: d0);
      await r.recordReview(1, 'a', remembered: true, now: DateTime(2026, 5, 11));
      await ProgressRepository().complete(
          childId: 1, lessonId: 'a', stars: 2, now: DateTime(2026, 5, 12));
      expect(await r.due(1, now: DateTime(2026, 5, 13)), isEmpty);
    });

    test('due lists are per child and oldest first', () async {
      final r = ReviewRepository();
      final p = ProgressRepository();
      await p.complete(childId: 1, lessonId: 'b', stars: 1, now: DateTime(2026, 5, 2));
      await p.complete(childId: 1, lessonId: 'a', stars: 1, now: DateTime(2026, 5, 1));
      await p.complete(childId: 2, lessonId: 'c', stars: 1, now: DateTime(2026, 5, 1));
      final now = DateTime(2026, 5, 20);
      expect(await r.due(1, now: now), ['a', 'b']);
      expect(await r.due(2, now: now), ['c']);
    });
  });
}
