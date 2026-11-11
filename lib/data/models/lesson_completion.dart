import '../../domain/gamification/achievements.dart';
import '../../domain/gamification/streak.dart';
import '../../domain/gamification/xp_rules.dart';

/// نتيجة إكمال درس: ما حصلت عليه الطفلة وما تغيّر.
class LessonCompletion {
  const LessonCompletion({
    required this.reward,
    required this.oldLevel,
    required this.newLevel,
    required this.totalXp,
    required this.streak,
    this.bonusXp = 0,
    this.bonusStars = 0,
    this.newBadges = const [],
  });

  final LessonReward reward;
  final int oldLevel;
  final int newLevel;
  final int totalXp;
  final StreakUpdate streak;

  /// مكافأة إكمال كل مهام اليوم (تُعطى مرة واحدة في اليوم).
  final int bonusXp;
  final int bonusStars;

  /// الشارات التي فُتحت بهذا الدرس.
  final List<AchievementDef> newBadges;

  bool get dailyBonusEarned => bonusXp > 0 || bonusStars > 0;
  int get gainedXp => reward.xp + bonusXp;
  bool get leveledUp => newLevel > oldLevel;
}
