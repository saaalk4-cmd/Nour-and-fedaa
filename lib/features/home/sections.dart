import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';

class AppSection {
  const AppSection(
    this.id,
    this.emoji,
    this.title,
    this.color, {
    this.soon = false,
  });

  final String id;
  final String emoji;
  final String title;
  final Color color;

  /// قسم يُبنى في مرحلة لاحقة (يظهر مقفولًا).
  final bool soon;
}

/// أقسام المحتوى (الفئات الأكبر من البراعم).
const appSections = <AppSection>[
  AppSection(SectionIds.quran, '📖', 'قرآني', Color(0xFF1F3A5F)),
  AppSection(SectionIds.prayer, '🕌', 'صلاتي', Color(0xFFCC6E4C)),
  AppSection(
      SectionIds.aqeedah, '🌙', 'ما لا يسع الطفل جهله', Color(0xFF4E7D6B)),
  AppSection(SectionIds.arabic, 'ع', 'عربيتي', Color(0xFF3F5F9E)),
  AppSection(SectionIds.adhkar, '🤲', 'أذكاري', Color(0xFF7A6BB0), soon: true),
  AppSection(SectionIds.akhlaq, '🌿', 'أخلاقي', Color(0xFF5F8F4E), soon: true),
];

/// بلاطات البراعم (2–4): وحدات المنهج الصغيرة.
const toddlerTiles = <AppSection>[
  AppSection('t_listen', '🎧', 'أسمع وأردد', Color(0xFFE6DCF2)),
  AppSection('t_letters', 'أ ب ت', 'أصوات الحروف', Color(0xFFD6EEE7)),
  AppSection('t_adab', '🌷', 'آدابي', Color(0xFFFBDDD2)),
  AppSection('t_know', '🌙', 'أتعرّف على ربي', Color(0xFFFBEBC8)),
  AppSection('t_salah', '🕌', 'أتعلّم الصلاة', Color(0xFFD9E7F5)),
  AppSection('t_akhlaq', '🌿', 'أخلاقي', Color(0xFFDDEBCF), soon: true),
];

AppSection? findSection(String id) {
  for (final s in [...appSections, ...toddlerTiles]) {
    if (s.id == id) return s;
  }
  return null;
}
