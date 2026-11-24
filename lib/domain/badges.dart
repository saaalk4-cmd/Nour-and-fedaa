/// شارة: مكافأة لطيفة بلا مقارنة بين الأطفال.
class BadgeDef {
  const BadgeDef(this.id, this.emoji, this.title, this.earnedBy);

  final String id;
  final String emoji;
  final String title;

  /// هل استحقها الطفل بهذه الإحصاءات؟
  final bool Function(BadgeStats) earnedBy;
}

class BadgeStats {
  const BadgeStats({required this.lessonsDone, required this.stars});

  final int lessonsDone;
  final int stars;
}

final badgeDefs = <BadgeDef>[
  BadgeDef('first_lesson', '🌱', 'أول درس', (s) => s.lessonsDone >= 1),
  BadgeDef('five_lessons', '🌿', 'خمسة دروس', (s) => s.lessonsDone >= 5),
  BadgeDef('ten_stars', '⭐', 'عشر نجوم', (s) => s.stars >= 10),
];

BadgeDef? badgeById(String id) {
  for (final b in badgeDefs) {
    if (b.id == id) return b;
  }
  return null;
}
