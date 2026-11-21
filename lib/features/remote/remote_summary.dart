import 'dart:convert';

import '../../core/audio/voice_service.dart' show VoiceService;
import '../../data/content/curriculum.dart';
import '../../data/models/child_report.dart';

/// درس أنهته البنت (للعرض على تليفون الأهل).
class DoneLesson {
  const DoneLesson({required this.title, required this.at, required this.mastered});

  final String title;
  final DateTime? at;

  /// كل الإجابات صحيحة من أول مرة (غير ذلك: يستحق مراجعة هادئة مع الأهل).
  final bool mastered;

  Map<String, dynamic> toJson() => {'t': title, 'at': at?.toIso8601String(), 'm': mastered};

  factory DoneLesson.fromJson(Map<String, dynamic> j) =>
      DoneLesson(title: j['t'] as String, at: DateTime.tryParse(j['at'] as String? ?? ''), mastered: j['m'] == true);
}

/// ملخص طفلة واحدة: أرقام فقط، بلا صوت ولا صور.
class ChildSummary {
  const ChildSummary({
    required this.name,
    required this.age,
    required this.todayMin,
    required this.weekMin,
    required this.totalMin,
    required this.stars,
    required this.lessonsDone,
    required this.lessonsTotal,
    required this.week,
    required this.day,
    required this.nextLesson,
    required this.recent,
    required this.review,
    required this.gamePlays,
    required this.lastActivity,
  });

  final String name;
  final int age;
  final int todayMin;

  /// دقائق آخر 7 أيام (الأقدم أولًا، آخر عنصر = اليوم).
  final List<int> weekMin;
  final int totalMin;
  final int stars;
  final int lessonsDone;
  final int lessonsTotal;

  /// موقعها في المنهج (null لو أنهت كل شيء أو لا يوجد).
  final int? week;
  final int? day;
  final String? nextLesson;
  final List<DoneLesson> recent;
  final List<String> review;
  final int gamePlays;
  final DateTime? lastActivity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'today': todayMin,
        'weekMin': weekMin,
        'total': totalMin,
        'stars': stars,
        'done': lessonsDone,
        'of': lessonsTotal,
        'week': week,
        'day': day,
        'next': nextLesson,
        'recent': [for (final r in recent) r.toJson()],
        'review': review,
        'games': gamePlays,
        'last': lastActivity?.toIso8601String(),
      };

  factory ChildSummary.fromJson(Map<String, dynamic> j) => ChildSummary(
        name: j['name'] as String? ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        todayMin: (j['today'] as num?)?.toInt() ?? 0,
        weekMin: [for (final m in (j['weekMin'] as List<dynamic>? ?? const [])) (m as num).toInt()],
        totalMin: (j['total'] as num?)?.toInt() ?? 0,
        stars: (j['stars'] as num?)?.toInt() ?? 0,
        lessonsDone: (j['done'] as num?)?.toInt() ?? 0,
        lessonsTotal: (j['of'] as num?)?.toInt() ?? 0,
        week: (j['week'] as num?)?.toInt(),
        day: (j['day'] as num?)?.toInt(),
        nextLesson: j['next'] as String?,
        recent: [for (final r in (j['recent'] as List<dynamic>? ?? const [])) DoneLesson.fromJson(r as Map<String, dynamic>)],
        review: [for (final r in (j['review'] as List<dynamic>? ?? const [])) r as String],
        gamePlays: (j['games'] as num?)?.toInt() ?? 0,
        lastActivity: DateTime.tryParse(j['last'] as String? ?? ''),
      );

  /// يبني الملخص من تقرير الأهل الموجود ومن مسار الأسبوع.
  static ChildSummary build({
    required ChildReport report,
    required PathWeek? path,
    required List<int> weekSeconds,
    required int gamePlays,
  }) {
    int? week;
    int? day;
    String? next;
    if (path != null && !path.finishedAll) {
      for (final d in path.days) {
        for (final n in d.nodes) {
          if (n.state == PathState.current) {
            week = path.week?.week;
            day = d.day;
            next = n.lesson.title;
          }
        }
      }
    }
    String clean(String t) => VoiceService.clean(t);
    return ChildSummary(
      name: report.child.name,
      age: report.child.age,
      todayMin: (report.usageTodaySeconds / 60).round(),
      weekMin: [for (final s in weekSeconds) (s / 60).round()],
      totalMin: (report.usageTotalSeconds / 60).round(),
      stars: report.profile.stars,
      lessonsDone: report.completed.length,
      lessonsTotal: report.lessonsTotal,
      week: week,
      day: day,
      nextLesson: next == null ? null : clean(next),
      recent: [
        for (final c in report.completed.take(8))
          DoneLesson(title: clean(c.lesson.title), at: c.completedAt, mastered: c.mastered),
      ],
      review: [for (final c in report.needsReview.take(5)) clean(c.lesson.title)],
      gamePlays: gamePlays,
      lastActivity: report.lastActivity,
    );
  }
}

/// ملخص الأسرة كله (مستند واحد على الخدمة).
class FamilySummary {
  const FamilySummary({required this.children, required this.dailyLimitMin, required this.madeAt});

  final List<ChildSummary> children;
  final int dailyLimitMin;
  final DateTime madeAt;

  String encode() => jsonEncode({
        'v': 1,
        'at': madeAt.toIso8601String(),
        'limit': dailyLimitMin,
        'children': [for (final c in children) c.toJson()],
      });

  static FamilySummary decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return FamilySummary(
      children: [for (final c in (j['children'] as List<dynamic>? ?? const [])) ChildSummary.fromJson(c as Map<String, dynamic>)],
      dailyLimitMin: (j['limit'] as num?)?.toInt() ?? 0,
      madeAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2000),
    );
  }
}
