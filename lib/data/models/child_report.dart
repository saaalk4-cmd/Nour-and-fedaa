import '../../domain/gamification/achievements.dart';
import '../../domain/gamification/streak.dart';
import '../content/lesson.dart';
import 'child.dart';
import 'gamification.dart';

/// صف تقدم خام من قاعدة البيانات.
class ProgressEntry {
  const ProgressEntry({
    required this.lessonId,
    required this.score,
    required this.completedAt,
  });

  final String lessonId;
  final int score;
  final DateTime? completedAt;
}

class CompletedLessonInfo {
  const CompletedLessonInfo({
    required this.lesson,
    required this.score,
    required this.completedAt,
  });

  final Lesson lesson;

  /// أفضل عدد إجابات صحيحة من أول مرة.
  final int score;
  final DateTime? completedAt;

  int get totalQuestions => lesson.questions.length;

  /// «متقَن»: كل الإجابات صحيحة من أول مرة. غير ذلك = يستحق المراجعة.
  bool get mastered => totalQuestions == 0 || score >= totalQuestions;
}

class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.done,
    required this.total,
  });

  final String category;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0.0 : done / total;
}

class ChildReport {
  const ChildReport({
    required this.child,
    required this.profile,
    required this.activeStreak,
    required this.lessonsTotal,
    required this.completedInAge,
    required this.completed,
    required this.needsReview,
    required this.categories,
    required this.badgesEarned,
    required this.badgesTotal,
    required this.usageTodaySeconds,
    required this.usageTotalSeconds,
    required this.lastActivity,
  });

  final Child child;
  final GamificationProfile profile;
  final int activeStreak;

  /// عدد دروس عمر الطفلة الحالي، وكم أكملت منها.
  final int lessonsTotal;
  final int completedInAge;

  /// كل ما أكملته (الأحدث أولًا).
  final List<CompletedLessonInfo> completed;

  /// دروس أُكملت لكن لم تُتقن بعد: تستحق مراجعة مع الوالد.
  final List<CompletedLessonInfo> needsReview;

  /// تقدم كل قسم (الأكثر تقدمًا أولًا).
  final List<CategoryProgress> categories;
  final int badgesEarned;
  final int badgesTotal;
  final int usageTodaySeconds;
  final int usageTotalSeconds;
  final DateTime? lastActivity;
}

class ReportBuilder {
  const ReportBuilder._();

  static ChildReport build({
    required Child child,
    required GamificationProfile profile,
    required List<Lesson> lessons,
    required List<ProgressEntry> progress,
    required int badgesEarned,
    required int usageTodaySeconds,
    required int usageTotalSeconds,
    required String today,
  }) {
    final forAge = lessons.where((l) => l.fitsAge(child.age)).toList();
    final byId = {for (final l in lessons) l.id: l};

    final completed = <CompletedLessonInfo>[];
    for (final p in progress) {
      final lesson = byId[p.lessonId];
      if (lesson == null) continue;
      completed.add(CompletedLessonInfo(
        lesson: lesson,
        score: p.score,
        completedAt: p.completedAt,
      ));
    }
    completed.sort((a, b) {
      final x = a.completedAt;
      final y = b.completedAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    final completedIds = completed.map((c) => c.lesson.id).toSet();
    final byCategory = <String, List<Lesson>>{};
    for (final l in forAge) {
      byCategory.putIfAbsent(l.category, () => []).add(l);
    }
    final categories = [
      for (final e in byCategory.entries)
        CategoryProgress(
          category: e.key,
          done: e.value.where((l) => completedIds.contains(l.id)).length,
          total: e.value.length,
        ),
    ]..sort((a, b) => b.fraction.compareTo(a.fraction));

    return ChildReport(
      child: child,
      profile: profile,
      activeStreak: StreakCalculator.activeStreak(
        lastDay: profile.lastActiveDay,
        today: today,
        current: profile.streakDays,
      ),
      lessonsTotal: forAge.length,
      completedInAge: forAge.where((l) => completedIds.contains(l.id)).length,
      completed: completed,
      needsReview: completed.where((c) => !c.mastered).toList(),
      categories: categories,
      badgesEarned: badgesEarned,
      badgesTotal: Achievements.earnable.length,
      usageTodaySeconds: usageTodaySeconds,
      usageTotalSeconds: usageTotalSeconds,
      lastActivity: completed.isEmpty ? null : completed.first.completedAt,
    );
  }
}
