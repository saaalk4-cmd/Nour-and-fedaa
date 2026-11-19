import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'lesson.dart';

/// يوم واحد في المنهج: عنوان + قائمة معرّفات مغامرات (دروس).
class CurriculumDay {
  const CurriculumDay({
    required this.day,
    required this.title,
    required this.lessonIds,
    this.earlyLessonIds = const [],
  });

  final int day;
  final String title;
  final List<String> lessonIds;

  /// مسار الصغيرات (3–4 سنوات): صور وصوت بلا قراءة. إن كان فارغًا تُستخدم lessonIds.
  final List<String> earlyLessonIds;
}

class CurriculumWeek {
  const CurriculumWeek({required this.week, required this.title, required this.days});

  final int week;
  final String title;
  final List<CurriculumDay> days;
}

/// اليوم الحالي لطفلة: أول يوم فيه مغامرة (تناسب عمرها) لم تكتمل بعد.
class TodayPlan {
  const TodayPlan({
    required this.week,
    required this.day,
    required this.adventures,
    required this.doneCount,
    required this.finishedAll,
  });

  final CurriculumWeek? week;
  final CurriculumDay? day;
  final List<Lesson> adventures;
  final int doneCount;

  /// true إن أنهت كل أيام المنهج الحالية.
  final bool finishedAll;
}

class Curriculum {
  const Curriculum(this.weeks);

  final List<CurriculumWeek> weeks;

  static Curriculum parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    return Curriculum((doc['weeks'] as List<dynamic>).map((w) {
      final m = w as Map<String, dynamic>;
      return CurriculumWeek(
        week: m['week'] as int,
        title: m['title'] as String,
        days: (m['days'] as List<dynamic>).map((d) {
          final dm = d as Map<String, dynamic>;
          return CurriculumDay(
            day: dm['day'] as int,
            title: dm['title'] as String,
            lessonIds: (dm['lessons'] as List<dynamic>).cast<String>(),
            earlyLessonIds:
                ((dm['earlyLessons'] as List<dynamic>?) ?? const []).cast<String>(),
          );
        }).toList(),
      );
    }).toList());
  }

  /// مغامرات اليوم المناسبة لعمر الطفلة (مسار الصغيرات إن وُجد).
  static List<Lesson> _mine(CurriculumDay d, int childAge, Map<String, Lesson> byId) {
    final early = childAge <= 4 && d.earlyLessonIds.isNotEmpty;
    final ids = early ? d.earlyLessonIds : d.lessonIds;
    return [
      for (final id in ids)
        if (byId[id] != null && byId[id]!.fitsAge(childAge)) byId[id]!,
    ];
  }

  /// يحدّد رحلة اليوم بناءً على التقدم (وليس التاريخ): لا ضغط ولا فقدان أيام.
  TodayPlan planFor({
    required int childAge,
    required List<Lesson> allLessons,
    required Set<String> completed,
  }) {
    final byId = {for (final l in allLessons) l.id: l};
    for (final w in weeks) {
      for (final d in w.days) {
        final mine = _mine(d, childAge, byId);
        if (mine.isEmpty) continue; // لا شيء مناسب لعمرها في هذا اليوم
        final done = mine.where((l) => completed.contains(l.id)).length;
        if (done < mine.length) {
          return TodayPlan(
            week: w,
            day: d,
            adventures: mine,
            doneCount: done,
            finishedAll: false,
          );
        }
      }
    }
    return const TodayPlan(
      week: null,
      day: null,
      adventures: [],
      doneCount: 0,
      finishedAll: true,
    );
  }

  /// «المسار»: أسبوع الطفلة الحالي كله مقسومًا إلى أيام. الترتيب صارم:
  /// المنجَز [PathState.done] (يمكن إعادته)، أول غير منجز [PathState.current]،
  /// وما بعده [PathState.locked]. لا شيء يُحذف ولا يُخصم.
  PathWeek pathFor({
    required int childAge,
    required List<Lesson> allLessons,
    required Set<String> completed,
  }) {
    final byId = {for (final l in allLessons) l.id: l};
    final plan = planFor(childAge: childAge, allLessons: allLessons, completed: completed);
    CurriculumWeek? target = plan.week;
    if (target == null) {
      // أنهت كل شيء: نعرض آخر أسبوع فيه دروس تناسبها، كله منجز.
      for (final w in weeks.reversed) {
        if (w.days.any((d) => _mine(d, childAge, byId).isNotEmpty)) {
          target = w;
          break;
        }
      }
    }
    if (target == null) return const PathWeek(week: null, days: [], finishedAll: true);

    var currentTaken = plan.finishedAll;
    final days = <PathDay>[];
    final seen = <String>{}; // درس يتكرر في الأسبوع يظهر مرة واحدة على المسار
    for (final d in target.days) {
      final mine = [
        for (final l in _mine(d, childAge, byId))
          if (seen.add(l.id)) l,
      ];
      if (mine.isEmpty) continue;
      final nodes = <PathNode>[];
      for (final l in mine) {
        if (completed.contains(l.id)) {
          nodes.add(PathNode(l, PathState.done));
        } else if (!currentTaken) {
          currentTaken = true;
          nodes.add(PathNode(l, PathState.current));
        } else {
          nodes.add(PathNode(l, PathState.locked));
        }
      }
      days.add(PathDay(day: d.day, title: d.title, nodes: nodes));
    }
    return PathWeek(week: target, days: days, finishedAll: plan.finishedAll);
  }
}

enum PathState { done, current, locked }

class PathNode {
  const PathNode(this.lesson, this.state);

  final Lesson lesson;
  final PathState state;
}

class PathDay {
  const PathDay({required this.day, required this.title, required this.nodes});

  final int day;
  final String title;
  final List<PathNode> nodes;

  /// 🎁 تُفتح حين تُنجَز كل مغامرات اليوم.
  bool get complete => nodes.every((n) => n.state == PathState.done);
}

class PathWeek {
  const PathWeek({required this.week, required this.days, required this.finishedAll});

  final CurriculumWeek? week;
  final List<PathDay> days;
  final bool finishedAll;

  Lesson? get current {
    for (final d in days) {
      for (final n in d.nodes) {
        if (n.state == PathState.current) return n.lesson;
      }
    }
    return null;
  }
}

class CurriculumRepository {
  static const String asset = 'assets/content/curriculum.json';

  Future<Curriculum> load() async => Curriculum.parse(await rootBundle.loadString(asset));
}
