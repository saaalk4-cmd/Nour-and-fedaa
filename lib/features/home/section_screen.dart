import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';
import '../achievements/trophy_room_screen.dart';
import '../hadith/hadith_section_screen.dart';
import '../lessons/lesson_list_screen.dart';
import '../quran/quran_screen.dart';
import 'sections.dart';

/// شاشة مؤقتة لكل قسم إلى أن يُبنى محتواه في المراحل التالية.
class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context) {
    if (sectionId == SectionIds.learn) return const LessonListScreen();
    const hadithAssets = {
      SectionIds.akhlaq: 'assets/content/akhlaq_hadith.json',
      SectionIds.adhkar: 'assets/content/adhkar_hadith.json',
      SectionIds.prayer: 'assets/content/prayer_hadith.json',
      SectionIds.seerah: 'assets/content/seerah_hadith.json',
    };
    final hadithAsset = hadithAssets[sectionId];
    if (hadithAsset != null) {
      final section = sectionById(sectionId);
      return HadithSectionScreen(
        title: '${section.title} ${section.emoji}',
        asset: hadithAsset,
      );
    }
    if (sectionId == SectionIds.quran) return const QuranScreen();
    if (sectionId == SectionIds.achievements) return const TrophyRoomScreen();
    final s = sectionById(sectionId);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text('قريبًا إن شاء الله',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
