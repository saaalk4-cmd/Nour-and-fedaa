import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';

class AppSection {
  const AppSection(this.id, this.emoji, this.title, this.color);
  final String id;
  final String emoji;
  final String title;
  final Color color;
}

const appSections = <AppSection>[
  AppSection(SectionIds.quran, '📖', 'قرآني', AppColors.teal),
  AppSection(SectionIds.prayer, '🕌', 'صلاتي', AppColors.leaf),
  AppSection(SectionIds.adhkar, '🌙', 'أذكاري', Color(0xFF6C7BD9)),
  AppSection(SectionIds.akhlaq, '❤️', 'أخلاقي الجميلة', AppColors.rose),
  AppSection(SectionIds.seerah, '📚', 'سيرة نبينا ﷺ', Color(0xFFE08E45)),
  AppSection(SectionIds.figures, '⭐', 'شخصيات أحبها', AppColors.sun),
  AppSection(SectionIds.prophets, '🌿', 'قصص الأنبياء', Color(0xFF4FAF8E)),
  AppSection(SectionIds.learn, '🧠', 'أتعلم', Color(0xFF58A6D8)),
  AppSection(SectionIds.achievements, '🌟', 'إنجازاتي', Color(0xFFB57EDC)),
];

AppSection sectionById(String id) =>
    appSections.firstWhere((s) => s.id == id, orElse: () => appSections.first);
