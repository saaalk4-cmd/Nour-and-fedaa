import 'lesson.dart';

/// التدرّج داخل المرحلة العمرية: درس صعوبته d يُفتح بعد إكمال درس واحد على الأقل
/// من صعوبة d-1. القفل دعوة لطيفة وليس عقوبة (تظهر رسالة «قريبًا ستصلين هنا!»).
class LessonProgression {
  const LessonProgression._();

  static bool isUnlocked(
    Lesson lesson,
    Iterable<Lesson> sameAge,
    Set<String> completed,
  ) {
    if (lesson.difficulty <= 1) return true;
    return sameAge.any(
      (l) => l.difficulty == lesson.difficulty - 1 && completed.contains(l.id),
    );
  }

  /// أول درس من المستوى الأسهل يُنصح بإكماله ليفتح هذا الدرس.
  static Lesson? prerequisite(Lesson lesson, Iterable<Lesson> sameAge) {
    for (final l in sameAge) {
      if (l.difficulty == lesson.difficulty - 1) return l;
    }
    return null;
  }

  /// الدرس المقترح تاليًا: أول درس مفتوح لم يُكمل بعد (بترتيب الملف).
  static Lesson? next(Iterable<Lesson> sameAge, Set<String> completed) {
    for (final l in sameAge) {
      if (!completed.contains(l.id) && isUnlocked(l, sameAge, completed)) {
        return l;
      }
    }
    return null;
  }
}
