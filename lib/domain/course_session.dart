import 'dart:convert';

/// حصة في منهج السنة: درسان (أو أكثر) يُؤخذان معًا، ضمن وحدة.
class CourseSession {
  const CourseSession({
    required this.n,
    required this.unit,
    required this.unitTitle,
    required this.lessons,
  });

  final int n;
  final int unit;
  final String unitTitle;
  final List<String> lessons;

  bool isDone(Set<String> done) => lessons.every(done.contains);

  factory CourseSession.fromJson(Map<String, dynamic> j) {
    final lessons = (j['lessons'] as List<dynamic>).cast<String>();
    if (lessons.isEmpty) throw const FormatException('حصة بلا دروس');
    return CourseSession(
      n: j['n'] as int,
      unit: j['unit'] as int,
      unitTitle: j['unit_title'] as String,
      lessons: lessons,
    );
  }

  /// يقرأ ملف منهج الفئة ويتحقق أن الحصص مرقّمة ١، ٢، ٣… بلا فجوات.
  static List<CourseSession> listFromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final list = [
      for (final e in j['sessions'] as List<dynamic>)
        CourseSession.fromJson(e as Map<String, dynamic>)
    ];
    for (var i = 0; i < list.length; i++) {
      if (list[i].n != i + 1) {
        throw FormatException('ترقيم الحصص غير متصل عند ${list[i].n}');
      }
    }
    return list;
  }
}

/// حصة اليوم: أول حصة لم تكتمل دروسها، أو الأخيرة إن اكتمل المنهج.
CourseSession? pickTodaySession(List<CourseSession> all, Set<String> done) {
  if (all.isEmpty) return null;
  for (final s in all) {
    if (!s.isDone(done)) return s;
  }
  return all.last;
}
