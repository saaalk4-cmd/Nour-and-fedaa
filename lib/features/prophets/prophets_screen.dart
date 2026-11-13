import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/quran.dart';
import '../lessons/lesson_list_screen.dart';

final prophetsContentProvider = FutureProvider<ProphetsContent>((ref) async {
  return ProphetsContent.parse(
    await rootBundle.loadString('assets/content/prophets_ayat.json'),
  );
});

/// قصص الأنبياء: آيات من القرآن (بمرجع السورة والآية) بلا أي صور للأنبياء.
class ProphetsScreen extends ConsumerWidget {
  const ProphetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(prophetsContentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('قصص الأنبياء 🌿')),
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
                    builder: (_) => const LessonListScreen(category: 'prophets', title: 'تدريب 🎯'),
                  ),
                ),
                icon: const Icon(Icons.sports_esports),
                label: const Text('تدريب ممتع 🎯', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 12),
            for (final v in c.verses) _VerseCard(verse: v),
            const SizedBox(height: 8),
            Text(
              'نص القرآن: ${c.sourceName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});

  final ProphetVerse verse;

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
            Text('${verse.emoji} ${verse.prophet}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(verse.title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(verse.text, style: const TextStyle(fontSize: 28, height: 2)),
            const SizedBox(height: 10),
            Text(verse.kidMeaning, style: const TextStyle(fontSize: 18, height: 1.6)),
            const SizedBox(height: 10),
            Text(verse.reference, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
