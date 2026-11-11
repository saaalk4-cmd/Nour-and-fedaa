import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/domain/gamification/level_system.dart';
import 'package:nourfadaa/domain/gamification/streak.dart';
import 'package:nourfadaa/domain/gamification/xp_rules.dart';

void main() {
  group('LevelSystem', () {
    test('level rises every 100 XP', () {
      expect(LevelSystem.levelForXp(0), 1);
      expect(LevelSystem.levelForXp(99), 1);
      expect(LevelSystem.levelForXp(100), 2);
      expect(LevelSystem.levelForXp(250), 3);
    });

    test('info is clamped at both ends', () {
      expect(LevelSystem.info(0).level, 1);
      expect(LevelSystem.info(1).name, 'بداية الرحلة');
      expect(LevelSystem.info(99).level, 5);
    });
  });

  group('XpRules', () {
    test('first completion rewards real learning', () {
      final r = XpRules.forLesson(
        firstTryCorrect: 2,
        totalQuestions: 3,
        isFirstCompletion: true,
      );
      expect(r.xp, 20); // 10 + 2*5
      expect(r.stars, 1);
      expect(r.perfect, isFalse);
    });

    test('perfect lesson gets bonus XP and 2 stars', () {
      final r = XpRules.forLesson(
        firstTryCorrect: 3,
        totalQuestions: 3,
        isFirstCompletion: true,
      );
      expect(r.xp, 30); // 10 + 15 + 5
      expect(r.stars, 2);
      expect(r.perfect, isTrue);
    });

    test('replaying a lesson gives small fixed XP and no stars', () {
      final r = XpRules.forLesson(
        firstTryCorrect: 3,
        totalQuestions: 3,
        isFirstCompletion: false,
      );
      expect(r.xp, XpRules.replayXp);
      expect(r.stars, 0);
    });

    test('out-of-range correct counts are clamped', () {
      final r = XpRules.forLesson(
        firstTryCorrect: 99,
        totalQuestions: 2,
        isFirstCompletion: true,
      );
      expect(r.xp, 25); // 10 + 2*5 + 5
    });
  });

  group('StreakCalculator', () {
    test('dayKey formats with zero padding', () {
      expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('first activity starts a streak of 1', () {
      final u = StreakCalculator.update(
        lastDay: null,
        today: '2026-11-12',
        current: 0,
        best: 0,
      );
      expect(u.current, 1);
      expect(u.welcomeBack, isFalse);
    });

    test('same day does not change the streak', () {
      final u = StreakCalculator.update(
        lastDay: '2026-11-12',
        today: '2026-11-12',
        current: 3,
        best: 3,
      );
      expect(u.current, 3);
      expect(u.extended, isFalse);
    });

    test('next day extends the streak and updates best', () {
      final u = StreakCalculator.update(
        lastDay: '2026-11-11',
        today: '2026-11-12',
        current: 3,
        best: 3,
      );
      expect(u.current, 4);
      expect(u.best, 4);
      expect(u.extended, isTrue);
    });

    test('a gap restarts gently with welcome-back and keeps best', () {
      final u = StreakCalculator.update(
        lastDay: '2026-11-05',
        today: '2026-11-12',
        current: 6,
        best: 6,
      );
      expect(u.current, 1);
      expect(u.best, 6);
      expect(u.welcomeBack, isTrue);
    });

    test('month and daylight-saving boundaries still count as 1 day', () {
      final u = StreakCalculator.update(
        lastDay: '2026-10-30',
        today: '2026-10-31',
        current: 2,
        best: 2,
      );
      expect(u.current, 3);
    });
  });
}
