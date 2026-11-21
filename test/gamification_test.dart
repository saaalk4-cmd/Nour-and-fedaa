import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/models/gamification.dart';

void main() {
  test('XP progress is derived correctly', () {
    const p = GamificationProfile(xp: 125, stars: 4, level: 2, streakDays: 1, dailyQuestsCompleted: 1, totalLessons: 1);
    expect(p.level, 2);
    expect(p.xpIntoLevel, 25);
    expect(p.xpToNextLevel, 75);
    expect(p.levelProgress, 0.25);
  });
}
