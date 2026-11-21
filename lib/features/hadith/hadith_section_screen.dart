import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/hadith.dart';
import '../lessons/lesson_list_screen.dart';

final hadithContentProvider =
    FutureProvider.family<HadithContent, String>((ref, asset) {
  return HadithRepository().load(asset);
});

/// قسم أحاديث/أذكار: يعرض النص بمصدره ودرجته، مع معنى مبسّط للطفلة.
/// يُستخدم لأخلاقي، أذكاري، صلاتي، وسيرة نبينا ﷺ (ملف JSON لكل قسم).
class HadithSectionScreen extends ConsumerWidget {
  const HadithSectionScreen({
    super.key,
    required this.title,
    required this.asset,
    required this.category,
  });

  final String title;
  final String category;
  final String asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(hadithContentProvider(asset));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل المحتوى')),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonListScreen(category: category, title: 'تدريب 🎯'),
                  ),
                ),
                icon: const Icon(Icons.sports_esports),
                label: const Text('تدريب ممتع 🎯', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 12),
            for (final h in c.hadiths) _HadithCard(hadith: h),
            const SizedBox(height: 8),
            Text(
              'المصدر: ${c.sourceName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HadithCard extends StatelessWidget {
  const _HadithCard({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${hadith.emoji} ${hadith.title}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('«${hadith.text}»',
                style: const TextStyle(fontSize: 26, height: 1.9)),
            const SizedBox(height: 10),
            Text(hadith.kidMeaning, style: const TextStyle(fontSize: 18, height: 1.6)),
            const SizedBox(height: 10),
            // تفاصيل المصدر لولي الأمر (صغيرة وهادئة).
            Text(
              '${hadith.excerpt ? '(جزء من الحديث) ' : ''}'
              '${hadith.narrator} — ${hadith.book} (${hadith.number}) — ${hadith.grade}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
