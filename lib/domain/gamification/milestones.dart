import '../../data/content/curriculum.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child_report.dart';

/// مكافأة تُمنح مرة واحدة عند إنهاء أسبوع، أو 4 أسابيع، أو منهج 24 أسبوعًا.
class Milestone {
  const Milestone({
    required this.id,
    required this.emoji,
    required this.title,
    required this.stars,
    required this.xp,
    this.week,
    this.isBadge = false,
    this.graduation = false,
  });

  /// معرّف يُحفظ في جدول الشارات. مكافآت الأسابيع تبدأ بـ ms_ ولا تظهر في غرفة الكؤوس.
  final String id;
  final String emoji;
  final String title;
  final int stars;
  final int xp;
  final int? week;

  /// شارة ظاهرة في غرفة الكؤوس (كل 4 أسابيع والتخرج).
  final bool isBadge;
  final bool graduation;

  static const String weekPrefix = 'ms_week_';
  static const String graduateId = 'graduate_24';
  static String monthId(int k) => 'month_$k';
}

class Milestones {
  const Milestones._();

  /// آخر أسبوع في المنهج الأول (التخرج).
  static const int graduationWeek = 24;

  /// دروس الأسبوع المناسبة لعمر الطفلة (نفس منطق «رحلتي اليوم»).
  static Set<String> weekLessons(
    CurriculumWeek w,
    int childAge,
    Map<String, Lesson> byId,
  ) {
    final ids = <String>{};
    for (final d in w.days) {
      final early = childAge <= 4 && d.earlyLessonIds.isNotEmpty;
      for (final id in (early ? d.earlyLessonIds : d.lessonIds)) {
        final l = byId[id];
        if (l != null && l.fitsAge(childAge)) ids.add(id);
      }
    }
    return ids;
  }

  /// المكافآت التي تحققت الآن ولم تُمنح بعد.
  static List<Milestone> newlyReached({
    required Curriculum curriculum,
    required int childAge,
    required List<Lesson> allLessons,
    required Set<String> completed,
    required Set<String> alreadyGranted,
  }) {
    final byId = {for (final l in allLessons) l.id: l};
    final weekDone = <int, bool>{};
    for (final w in curriculum.weeks) {
      final ids = weekLessons(w, childAge, byId);
      weekDone[w.week] = ids.isNotEmpty && ids.every(completed.contains);
    }
    final out = <Milestone>[];
    for (final w in curriculum.weeks) {
      if (weekDone[w.week] != true) continue;
      final wid = '${Milestone.weekPrefix}${w.week}';
      if (!alreadyGranted.contains(wid)) {
        out.add(Milestone(
          id: wid,
          emoji: '🌟',
          title: 'أنهيتِ الأسبوع ${w.week}!',
          stars: 3,
          xp: 20,
          week: w.week,
        ));
      }
      if (w.week % 4 == 0) {
        final block = [for (var k = w.week - 3; k <= w.week; k++) k];
        final allFour = block.every((k) => weekDone[k] == true);
        if (!allFour) continue;
        if (w.week == graduationWeek) {
          if (!alreadyGranted.contains(Milestone.graduateId)) {
            out.add(const Milestone(
              id: Milestone.graduateId,
              emoji: '🎓',
              title: 'تخرّجتِ من رحلتك الأولى!',
              stars: 25,
              xp: 100,
              week: graduationWeek,
              isBadge: true,
              graduation: true,
            ));
          }
        } else {
          final k = w.week ~/ 4;
          final id = Milestone.monthId(k);
          if (!alreadyGranted.contains(id)) {
            out.add(Milestone(
              id: id,
              emoji: '🏅',
              title: 'أكملتِ 4 أسابيع! ($k)',
              stars: 10,
              xp: 50,
              week: w.week,
              isBadge: true,
            ));
          }
        }
      }
    }
    return out;
  }
}

/// مراجعة ذكية بقواعد بسيطة: درس أُكمل وكانت إجابات أول محاولة فيه أقل من عدد أسئلته.
class ReviewPicker {
  const ReviewPicker._();

  static Lesson? pick({
    required List<ProgressEntry> entries,
    required Map<String, Lesson> byId,
    required int childAge,
    Set<String> exclude = const {},
  }) {
    Lesson? best;
    double bestRatio = 1;
    DateTime? bestTime;
    for (final e in entries) {
      final l = byId[e.lessonId];
      if (l == null || l.questions.isEmpty || exclude.contains(l.id)) continue;
      if (!l.fitsAge(childAge) || l.source.type != 'educational') continue;
      final ratio = e.score / l.questions.length;
      if (ratio >= 1) continue;
      final t = e.completedAt;
      final better = best == null ||
          ratio < bestRatio ||
          (ratio == bestRatio && t != null && (bestTime == null || t.isBefore(bestTime)));
      if (better) {
        best = l;
        bestRatio = ratio;
        bestTime = t;
      }
    }
    return best;
  }
}
