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
  });

  final LessonReward reward;
  final int oldLevel;
  final int newLevel;
  final int totalXp;
  final StreakUpdate streak;

  bool get leveledUp => newLevel > oldLevel;
}
