/// لقطة من تقدم الطفلة تُقيَّم عليها شروط الشارات.
class AchievementStats {
  const AchievementStats({
    required this.lessons,
    required this.xp,
    required this.level,
    required this.stars,
    required this.bestStreak,
    required this.correctAnswers,
    required this.bonusDays,
    required this.perfectNow,
  });

  final int lessons;
  final int xp;
  final int level;
  final int stars;
  final int bestStreak;

  /// مجموع أفضل نتيجة (إجابات صحيحة من أول مرة) في كل درس.
  final int correctAnswers;

  /// عدد الأيام التي أكملت فيها كل مهام اليوم.
  final int bonusDays;

  /// هل كان الدرس الذي أُكمل الآن بلا أي خطأ (للمرة الأولى).
  final bool perfectNow;
}

class AchievementDef {
  AchievementDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    this.test,
    this.comingSoon = false,
  });

  final String id;
  final String emoji;
  final String title;

  /// وصف لطيف لما يجب فعله (يظهر والشارة مقفلة).
  final String description;
  final bool Function(AchievementStats s)? test;

  /// شارة مرتبطة بمحتوى لم يُضف بعد: تظهر «قريبًا» ولا تُمنح.
  final bool comingSoon;
}

class Achievements {
  const Achievements._();

  static final List<AchievementDef> all = [
    AchievementDef(
      id: 'first_lesson',
      emoji: '🏅',
      title: 'أول درس',
      description: 'أكملي أول درس لكِ',
      test: (s) => s.lessons >= 1,
    ),
    AchievementDef(
      id: 'five_lessons',
      emoji: '🧭',
      title: 'مستكشفة المعرفة',
      description: 'أكملي 5 دروس',
      test: (s) => s.lessons >= 5,
    ),
    AchievementDef(
      id: 'xp_100',
      emoji: '⚡',
      title: 'أول 100 XP',
      description: 'اجمعي 100 XP',
      test: (s) => s.xp >= 100,
    ),
    AchievementDef(
      id: 'streak_3',
      emoji: '🔥',
      title: '3 أيام متتالية',
      description: 'تعلّمي 3 أيام وراء بعض',
      test: (s) => s.bestStreak >= 3,
    ),
    AchievementDef(
      id: 'streak_7',
      emoji: '🌟',
      title: 'أسبوع كامل',
      description: 'تعلّمي 7 أيام وراء بعض',
      test: (s) => s.bestStreak >= 7,
    ),
    AchievementDef(
      id: 'correct_10',
      emoji: '✅',
      title: '10 إجابات صحيحة',
      description: 'أجيبي 10 أسئلة صح من أول مرة',
      test: (s) => s.correctAnswers >= 10,
    ),
    AchievementDef(
      id: 'perfect_lesson',
      emoji: '💎',
      title: 'درس بلا أخطاء',
      description: 'أنهي درسًا وكل إجاباتك صح من أول مرة',
      test: (s) => s.perfectNow,
    ),
    AchievementDef(
      id: 'daily_hero',
      emoji: '🎯',
      title: 'بطلة المهام',
      description: 'أكملي كل مهام اليوم',
      test: (s) => s.bonusDays >= 1,
    ),
    AchievementDef(
      id: 'stars_10',
      emoji: '⭐',
      title: '10 نجوم',
      description: 'اجمعي 10 نجوم',
      test: (s) => s.stars >= 10,
    ),
    AchievementDef(
      id: 'level_3',
      emoji: '🏆',
      title: 'متعلمة نشيطة',
      description: 'ارتقي إلى المستوى 3',
      test: (s) => s.level >= 3,
    ),
    // شارات المحتوى الديني: لا تُمنح قبل وجود الدروس الموثقة.
    AchievementDef(
      id: 'first_surah',
      emoji: '📖',
      title: 'أول سورة',
      description: 'قريبًا ستصلين هنا!',
      comingSoon: true,
    ),
    AchievementDef(
      id: 'first_dua',
      emoji: '🌙',
      title: 'أول دعاء',
      description: 'قريبًا ستصلين هنا!',
      comingSoon: true,
    ),
    AchievementDef(
      id: 'learned_wudu',
      emoji: '💧',
      title: 'تعلّمتُ الوضوء',
      description: 'قريبًا ستصلين هنا!',
      comingSoon: true,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// الشارات القابلة للفتح الآن (بدون «قريبًا»).
  static List<AchievementDef> get earnable =>
      all.where((a) => !a.comingSoon).toList();

  /// الشارات الجديدة التي تحققت شروطها ولم تُمنح من قبل.
  static List<AchievementDef> newlyEarned(
    AchievementStats stats,
    Set<String> alreadyEarned,
  ) {
    return [
      for (final a in all)
        if (!a.comingSoon &&
            !alreadyEarned.contains(a.id) &&
            (a.test?.call(stats) ?? false))
          a,
    ];
  }
}
