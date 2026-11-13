import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/hadith.dart';

final akhlaqHadithProvider = FutureProvider<HadithContent>((ref) {
  return HadithRepository().load('assets/content/akhlaq_hadith.json');
});

/// أخلاقي الجميلة: أحاديث صحيحة قصيرة بمصدرها ودرجتها، مع معنى مبسّط للطفلة.
class AkhlaqScreen extends ConsumerWidget {
  const AkhlaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(akhlaqHadithProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('أخلاقي الجميلة ❤️')),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل الأحاديث')),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              '${hadith.narrator} — ${hadith.book} (${hadith.number}) — ${hadith.grade}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
