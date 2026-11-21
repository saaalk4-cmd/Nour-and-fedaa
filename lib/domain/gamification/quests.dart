class QuestDef {
  const QuestDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.target,
  });

  final String id;
  final String title;
  final String emoji;
  final int target;
}

class QuestProgress {
  const QuestProgress({required this.def, required this.progress});

  final QuestDef def;
  final int progress;

  bool get done => progress >= def.target;
  double get fraction {
    if (def.target <= 0 || progress >= def.target) return 1.0;
    if (progress <= 0) return 0.0;
    return progress / def.target;
  }
}

class DailyQuestsState {
  const DailyQuestsState({required this.quests, required this.bonusGiven});

  final List<QuestProgress> quests;
  final bool bonusGiven;

  bool get allDone => quests.isNotEmpty && quests.every((q) => q.done);
  int get doneCount => quests.where((q) => q.done).length;
}

/// مهام اليوم: قليلة (2-3) وخفيفة. الهدف الاستمرارية وليس الضغط.
class DailyQuests {
  const DailyQuests._();

  static const String lessonOne = 'lesson_one';
  static const String correctAnswers = 'correct_answers';
  static const String xpToday = 'xp_today';

  /// صف خاص يسجّل أن المكافأة اليومية أُعطيت (مرة واحدة في اليوم).
  static const String bonusId = '_bonus';
  static const int bonusXp = 10;
  static const int bonusStars = 1;

  /// عدد المهام والصعوبة يختلفان حسب العمر (3-4 أبسط من 5-6).
  static List<QuestDef> forAge(int age) {
    if (age <= 4) {
      return const [
        QuestDef(id: lessonOne, title: 'أكملي درسًا واحدًا', emoji: '📚', target: 1),
        QuestDef(id: correctAnswers, title: 'أجيبي عن سؤالين صح', emoji: '⭐', target: 2),
      ];
    }
    return const [
      QuestDef(id: lessonOne, title: 'أكملي درسًا واحدًا', emoji: '📚', target: 1),
      QuestDef(id: correctAnswers, title: 'أجيبي عن 3 أسئلة صح', emoji: '⭐', target: 3),
      QuestDef(id: xpToday, title: 'اجمعي 25 XP', emoji: '⚡', target: 25),
    ];
  }

  /// يحسب التقدم الجديد لمهمة بعد إكمال درس (لا يتجاوز الهدف).
  static int applyEvent(
    String questId,
    int progress,
    int target, {
    required int lessons,
    required int correct,
    required int xp,
  }) {
    final add = switch (questId) {
      lessonOne => lessons,
      correctAnswers => correct,
      xpToday => xp,
      _ => 0,
    };
    final next = progress + add;
    return next > target ? target : next;
  }
}
