class GamificationProfile {
  const GamificationProfile({
    required this.xp,
    required this.stars,
    required this.level,
    required this.streakDays,
    required this.dailyQuestsCompleted,
    required this.totalLessons,
  });

  final int xp;
  final int stars;
  final int level;
  final int streakDays;
  final int dailyQuestsCompleted;
  final int totalLessons;

  int get xpIntoLevel => xp % 100;
  int get xpToNextLevel => 100 - xpIntoLevel;
  double get levelProgress => xpIntoLevel / 100;
}
