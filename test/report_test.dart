import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/models/child_report.dart';
import 'package:nourfadaa/data/models/gamification.dart';
import 'package:nourfadaa/domain/format.dart';

void main() {
  final lessons = ContentRepository.parseLessons(
    File(ContentRepository.learnAsset).readAsStringSync(),
  );
  const fedaa = Child(id: 2, name: 'فداء', age: 5);

  ChildReport build(List<ProgressEntry> progress, {String? lastDay, int streak = 0}) {
    return ReportBuilder.build(
      child: fedaa,
      profile: GamificationProfile(
        xp: 50,
        stars: 3,
        level: 1,
        streakDays: streak,
        dailyQuestsCompleted: 0,
        totalLessons: progress.length,
        lastActiveDay: lastDay,
      ),
      lessons: lessons,
      progress: progress,
      badgesEarned: 2,
      usageTodaySeconds: 125,
      usageTotalSeconds: 4000,
      today: '2026-11-12',
    );
  }

  test('empty progress gives an empty but valid report', () {
    final r = build(const []);
    expect(r.completed, isEmpty);
    expect(r.needsReview, isEmpty);
    expect(r.lastActivity, isNull);
    expect(r.lessonsTotal, greaterThan(0));
    expect(r.completedInAge, 0);
    expect(r.activeStreak, 0);
  });

  test('completed lessons are sorted newest first and mastery is detected', () {
    final letters = lessons.firstWhere((l) => l.id == 'learn_letters_alef_ba_ta');
    final add = lessons.firstWhere((l) => l.id == 'learn_add_simple');
    final r = build([
      ProgressEntry(
        lessonId: letters.id,
        score: letters.questions.length,
        completedAt: DateTime(2026, 11, 10),
      ),
      ProgressEntry(
        lessonId: add.id,
        score: 1,
        completedAt: DateTime(2026, 11, 11),
      ),
    ], lastDay: '2026-11-11', streak: 2);

    expect(r.completed.first.lesson.id, add.id);
    expect(r.lastActivity, DateTime(2026, 11, 11));
    expect(r.needsReview.map((c) => c.lesson.id), [add.id]);
    expect(r.completedInAge, 2);
    expect(r.activeStreak, 2);
    expect(r.categories.single.done, 2);
  });

  test('unknown lesson ids in progress are ignored safely', () {
    final r = build([
      ProgressEntry(lessonId: 'removed_lesson', score: 1, completedAt: DateTime(2026, 11, 1)),
    ]);
    expect(r.completed, isEmpty);
  });

  group('format', () {
    test('formatUsage', () {
      expect(formatUsage(10), 'أقل من دقيقة');
      expect(formatUsage(125), '2 دقيقة');
      expect(formatUsage(3600), '1 ساعة');
      expect(formatUsage(3900), '1 ساعة و5 دقيقة');
    });

    test('describeLastActivity uses calendar days', () {
      final now = DateTime(2026, 11, 12, 0, 5);
      expect(describeLastActivity(null, now), 'لا يوجد نشاط بعد');
      expect(describeLastActivity(DateTime(2026, 11, 12, 23, 59), now), 'اليوم');
      expect(describeLastActivity(DateTime(2026, 11, 11, 23, 59), now), 'أمس');
      expect(describeLastActivity(DateTime(2026, 11, 10), now), 'قبل يومين');
      expect(describeLastActivity(DateTime(2026, 11, 7), now), 'قبل 5 أيام');
      expect(describeLastActivity(DateTime(2026, 10, 1), now), 'قبل 42 يومًا');
    });
  });
}
