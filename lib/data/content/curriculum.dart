import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'lesson.dart';

/// يوم واحد في المنهج: عنوان + قائمة معرّفات مغامرات (دروس).
class CurriculumDay {
  const CurriculumDay({required this.day, required this.title, required this.lessonIds});

  final int day;
  final String title;
  final List<String> lessonIds;
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
          );
        }).toList(),
      );
    }).toList());
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
        final mine = [
          for (final id in d.lessonIds)
            if (byId[id] != null && byId[id]!.fitsAge(childAge)) byId[id]!,
        ];
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
}

class CurriculumRepository {
  static const String asset = 'assets/content/curriculum.json';

  Future<Curriculum> load() async => Curriculum.parse(await rootBundle.loadString(asset));
}
