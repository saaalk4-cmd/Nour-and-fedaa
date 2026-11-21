import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/domain/gamification/achievements.dart';

AchievementStats stats({
  int lessons = 0,
  int xp = 0,
  int level = 1,
  int stars = 0,
  int bestStreak = 0,
  int correct = 0,
  int bonusDays = 0,
  bool perfectNow = false,
}) =>
    AchievementStats(
      lessons: lessons,
      xp: xp,
      level: level,
      stars: stars,
      bestStreak: bestStreak,
      correctAnswers: correct,
      bonusDays: bonusDays,
      perfectNow: perfectNow,
    );

void main() {
  test('ids are unique', () {
    final ids = Achievements.all.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('nothing is earned at the start', () {
    expect(Achievements.newlyEarned(stats(), <String>{}), isEmpty);
  });

  test('first lesson earns first_lesson only', () {
    final got = Achievements.newlyEarned(stats(lessons: 1), <String>{});
    expect(got.map((a) => a.id), ['first_lesson']);
  });

  test('already earned badges are not granted twice', () {
    final got = Achievements.newlyEarned(
      stats(lessons: 1),
      <String>{'first_lesson'},
    );
    expect(got, isEmpty);
  });

  test('several thresholds can be earned together', () {
    final got = Achievements.newlyEarned(
      stats(lessons: 5, xp: 120, level: 2, bestStreak: 3, correct: 10, perfectNow: true),
      <String>{},
    ).map((a) => a.id).toSet();
    expect(
      got,
      containsAll(<String>[
        'first_lesson',
        'five_lessons',
        'xp_100',
        'streak_3',
        'correct_10',
        'perfect_lesson',
      ]),
    );
    expect(got, isNot(contains('level_3')));
  });

  test('coming-soon religious badges are never granted', () {
    final got = Achievements.newlyEarned(
      stats(lessons: 99, xp: 9999, level: 9, stars: 99, bestStreak: 99, correct: 99, bonusDays: 9, perfectNow: true),
      <String>{},
    );
    for (final a in got) {
      expect(a.comingSoon, isFalse);
    }
    expect(Achievements.all.where((a) => a.comingSoon), isNotEmpty);
    expect(Achievements.earnable.every((a) => a.test != null), isTrue);
  });
}
