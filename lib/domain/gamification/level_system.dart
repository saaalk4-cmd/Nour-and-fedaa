class LevelInfo {
  const LevelInfo(this.level, this.icon, this.name);

  final int level;
  final String icon;
  final String name;
}

/// المستويات: كل 100 XP مستوى جديد. بعد آخر اسم يبقى الاسم الأخير.
class LevelSystem {
  const LevelSystem._();

  static const int xpPerLevel = 100;

  static const List<LevelInfo> _tiers = [
    LevelInfo(1, '🌱', 'بداية الرحلة'),
    LevelInfo(2, '🌿', 'مستكشفة صغيرة'),
    LevelInfo(3, '⭐', 'متعلمة نشيطة'),
    LevelInfo(4, '🏆', 'بطلة التعلم'),
    LevelInfo(5, '🌟', 'نجمة المعرفة'),
  ];

  static int levelForXp(int xp) => (xp < 0 ? 0 : xp) ~/ xpPerLevel + 1;

  static LevelInfo info(int level) {
    var i = level - 1;
    if (i < 0) i = 0;
    if (i >= _tiers.length) i = _tiers.length - 1;
    return _tiers[i];
  }
}
