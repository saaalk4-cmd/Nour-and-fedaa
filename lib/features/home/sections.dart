import 'package:flutter/material.dart';

import '../../core/design/art.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';

class AppSection {
  const AppSection(this.id, this.emoji, this.title, this.color, this.art);
  final String id;
  final String emoji;

  /// أيقونة القسم المرسومة (assets/art)؛ الإيموجي يبقى للنصوص فقط.
  final String art;
  final String title;
  final Color color;
}

const appSections = <AppSection>[
  AppSection(SectionIds.quran, '📖', 'قرآني', AppColors.teal, Art.secQuran),
  AppSection(SectionIds.prayer, '🕌', 'صلاتي', AppColors.leaf, Art.secPrayer),
  AppSection(SectionIds.adhkar, '🌙', 'أذكاري', Color(0xFF6C7BD9), Art.secAdhkar),
  AppSection(SectionIds.akhlaq, '❤️', 'أخلاقي الجميلة', AppColors.rose, Art.secAkhlaq),
  AppSection(SectionIds.seerah, '📚', 'سيرة نبينا ﷺ', Color(0xFFE08E45), Art.secSeerah),
  AppSection(SectionIds.figures, '⭐', 'شخصيات أحبها', AppColors.sun, Art.secFigures),
  AppSection(SectionIds.prophets, '🌿', 'قصص الأنبياء', Color(0xFF4FAF8E), Art.secProphets),
  AppSection(SectionIds.learn, '🧠', 'أتعلم', Color(0xFF58A6D8), Art.secLearn),
  AppSection(SectionIds.achievements, '🌟', 'إنجازاتي', Color(0xFFB57EDC), Art.secAchievements),
];

AppSection sectionById(String id) =>
    appSections.firstWhere((s) => s.id == id, orElse: () => appSections.first);
