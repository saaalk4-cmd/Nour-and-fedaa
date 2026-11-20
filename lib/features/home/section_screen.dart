import 'package:flutter/material.dart';
import '../../core/design/art.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/lesson.dart';
import '../../data/providers.dart';
import '../lessons/kid_section_screen.dart';
import '../lessons/toddler_section_screen.dart';

import '../../data/repositories/settings_repository.dart';
import '../achievements/trophy_room_screen.dart';
import '../hadith/hadith_section_screen.dart';
import '../lessons/lesson_list_screen.dart';
import '../prophets/prophets_screen.dart';
import '../quran/hifz_screens.dart';
import 'sections.dart';

/// شاشة مؤقتة لكل قسم إلى أن يُبنى محتواه في المراحل التالية.
class SectionScreen extends ConsumerWidget {
  const SectionScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // محرك المحتوى حسب العمر: الصغيرات (3–4) يرين بطاقات صور فقط في كل الأقسام التعليمية.
    final c = ref.watch(selectedChildProvider).valueOrNull;
    // قرآني: شاشة الأجزاء والحفظ والمراجعة للبنتين (نور سماع فقط داخلها).
    if (sectionId == SectionIds.quran) return const QuranHomeScreen();
    if (c != null &&
        ContentLevel.forAge(c.age).pictureOnly &&
        sectionId != SectionIds.achievements) {
      final section = sectionById(sectionId);
      return ToddlerSectionScreen(
        category: sectionId,
        title: section.title,
        child: c,
      );
    }
    if (c != null && sectionId != SectionIds.achievements) {
      // فداء (5): بطاقات صور ناطقة؛ شاشات النص الكاملة للأهل بالضغط المطوّل على 📋.
      final section = sectionById(sectionId);
      return KidSectionScreen(
        category: sectionId,
        title: section.title,
        child: c,
        parentView: (_) => _legacy(sectionId),
      );
    }
    return _legacy(sectionId);
  }

  Widget _legacy(String sectionId) {
    if (sectionId == SectionIds.learn) return const LessonListScreen();
    const hadithAssets = {
      SectionIds.akhlaq: 'assets/content/akhlaq_hadith.json',
      SectionIds.adhkar: 'assets/content/adhkar_hadith.json',
      SectionIds.prayer: 'assets/content/prayer_hadith.json',
      SectionIds.seerah: 'assets/content/seerah_hadith.json',
      SectionIds.figures: 'assets/content/figures_hadith.json',
    };
    final hadithAsset = hadithAssets[sectionId];
    if (hadithAsset != null) {
      final section = sectionById(sectionId);
      return HadithSectionScreen(
        title: section.title,
        asset: hadithAsset,
        category: sectionId,
      );
    }
    if (sectionId == SectionIds.prophets) return const ProphetsScreen();
    if (sectionId == SectionIds.quran) return const QuranHomeScreen();
    if (sectionId == SectionIds.achievements) return const TrophyRoomScreen();
    final s = sectionById(sectionId);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtImage(s.art, width: 120, height: 120),
            const SizedBox(height: 16),
            const Text('قريبًا إن شاء الله', style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
