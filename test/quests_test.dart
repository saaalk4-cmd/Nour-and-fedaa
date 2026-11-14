import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/domain/gamification/quests.dart';
import 'package:nourfadaa/domain/gamification/streak.dart';

void main() {
  group('DailyQuests', () {
    test('age 3-4 gets 2 simple quests, age 5-6 gets 3', () {
      expect(DailyQuests.forAge(3).length, 2);
      expect(DailyQuests.forAge(5).length, 3);
      expect(DailyQuests.forAge(5).map((q) => q.id), contains(DailyQuests.xpToday));
    });

    test('applyEvent adds progress and never exceeds the target', () {
      expect(
        DailyQuests.applyEvent(DailyQuests.lessonOne, 0, 1, lessons: 1, correct: 3, xp: 30),
        1,
      );
      expect(
        DailyQuests.applyEvent(DailyQuests.correctAnswers, 1, 3, lessons: 1, correct: 5, xp: 0),
        3,
      );
      expect(
        DailyQuests.applyEvent(DailyQuests.xpToday, 10, 25, lessons: 1, correct: 0, xp: 20),
        25,
      );
      expect(
        DailyQuests.applyEvent('unknown', 0, 5, lessons: 1, correct: 1, xp: 1),
        0,
      );
    });

    test('state reports completion', () {
      final defs = DailyQuests.forAge(3);
      final partial = DailyQuestsState(
        quests: [
          QuestProgress(def: defs[0], progress: 1),
          QuestProgress(def: defs[1], progress: 1),
        ],
        bonusGiven: false,
      );
      expect(partial.allDone, isFalse);
      expect(partial.doneCount, 1);
      final full = DailyQuestsState(
        quests: [
          QuestProgress(def: defs[0], progress: 1),
          QuestProgress(def: defs[1], progress: 2),
        ],
        bonusGiven: true,
      );
      expect(full.allDone, isTrue);
    });
  });

  group('activeStreak', () {
    test('keeps the streak if active today or yesterday', () {
      expect(
        StreakCalculator.activeStreak(lastDay: '2026-11-12', today: '2026-11-12', current: 4),
        4,
      );
      expect(
        StreakCalculator.activeStreak(lastDay: '2026-11-11', today: '2026-11-12', current: 4),
        4,
      );
    });

    test('shows 0 (gently) after a gap or with no activity', () {
      expect(
        StreakCalculator.activeStreak(lastDay: '2026-11-08', today: '2026-11-12', current: 4),
        0,
      );
      expect(
        StreakCalculator.activeStreak(lastDay: null, today: '2026-11-12', current: 0),
        0,
      );
    });
  });
}
