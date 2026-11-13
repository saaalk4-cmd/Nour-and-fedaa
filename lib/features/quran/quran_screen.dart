import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/quran.dart';
import '../lessons/lesson_list_screen.dart';

final quranContentProvider = FutureProvider<QuranContent>((ref) {
  return QuranRepository().load();
});

/// قرآني: قائمة السور القصيرة، ثم قراءة آية آية بنص مأخوذ حرفيًا من Tanzil.
class QuranScreen extends ConsumerWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(quranContentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('قرآني 📖')),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل السور')),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LessonListScreen(category: 'quran', title: 'تدريب 🎯'),
                  ),
                ),
                icon: const Icon(Icons.sports_esports),
                label: const Text('تدريب ممتع 🎯', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 12),
            for (final s in c.surahs)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(child: Text('${s.surahNumber}')),
                  title: Text('سورة ${s.name}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.ayahs.length} آيات'),
                  trailing: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SurahReaderScreen(surah: s, content: c),
                    ),
                  ),
                ),
              ),
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

class SurahReaderScreen extends StatelessWidget {
  const SurahReaderScreen({super.key, required this.surah, required this.content});

  final Surah surah;
  final QuranContent content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('سورة ${surah.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // السورة التي ليست الفاتحة تبدأ بالبسملة (ليست آية منها) كعنوان فقط.
          if (surah.surahNumber != 1 && surah.surahNumber != 9)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, height: 2),
              ),
            ),
          for (final a in surah.ayahs)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(radius: 16, child: Text('${a.number}')),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        a.text,
                        style: const TextStyle(fontSize: 30, height: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'اسمعي السورة من أحد والديكِ، وردّديها معه آية آية 💛',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'المصدر: ${content.sourceName}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
