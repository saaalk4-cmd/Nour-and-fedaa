class LessonReward {
  const LessonReward({
    required this.xp,
    required this.stars,
    required this.isFirstCompletion,
    required this.perfect,
  });

  final int xp;
  final int stars;
  final bool isFirstCompletion;
  final bool perfect;
}

/// قواعد المكافآت: مرتبطة بإتمام التعلم فعلًا (خطوات الدرس + الأسئلة).
/// إعادة الدرس تعطي XP قليلًا ثابتًا ولا تعطي نجومًا، فلا يمكن جمع النقاط بالتكرار.
class XpRules {
  const XpRules._();

  static const int lessonBase = 10;
  static const int perFirstTryCorrect = 5;
  static const int perfectBonus = 5;
  static const int replayXp = 5;

  static LessonReward forLesson({
    required int firstTryCorrect,
    required int totalQuestions,
    required bool isFirstCompletion,
  }) {
    var correct = firstTryCorrect;
    if (correct < 0) correct = 0;
    if (correct > totalQuestions) correct = totalQuestions;
    final perfect = totalQuestions > 0 && correct == totalQuestions;

    if (!isFirstCompletion) {
      return const LessonReward(
        xp: replayXp,
        stars: 0,
        isFirstCompletion: false,
        perfect: false,
      );
    }
    final xp = lessonBase +
        correct * perFirstTryCorrect +
        (perfect ? perfectBonus : 0);
    return LessonReward(
      xp: xp,
      stars: perfect ? 2 : 1,
      isFirstCompletion: true,
      perfect: perfect,
    );
  }
}
