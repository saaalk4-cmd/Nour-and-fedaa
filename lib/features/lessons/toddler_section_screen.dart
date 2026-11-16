import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// قسم الصغيرات (3–4 سنوات): بطاقات صور كبيرة، بلا نصوص طويلة ولا مصادر.
/// الضغط على البطاقة يفتح الدرس بواجهة «صورة + صوت + لمس».
class ToddlerSectionScreen extends ConsumerWidget {
  const ToddlerSectionScreen({super.key, required this.category, required this.title, required this.child});

  final String category;
  final String title;
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(child.id)).valueOrNull ?? const <String>{};
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل الدروس')),
        data: (all) {
          final mine = all.where((l) => l.category == category && l.fitsAge(child.age)).toList();
          if (mine.isEmpty) {
            return const Center(child: Text('🌟', style: TextStyle(fontSize: 96)));
          }
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
            children: [
              for (final l in mine)
                _PictureCard(lesson: l, done: done.contains(l.id)),
            ],
          );
        },
      ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({required this.lesson, required this.done});

  final Lesson lesson;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: done ? const Color(0xFFE3F5DE) : Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(34),
      child: InkWell(
        borderRadius: BorderRadius.circular(34),
        onTap: () => context.push('/lesson/${lesson.id}'),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lesson.emoji, style: const TextStyle(fontSize: 76)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      lesson.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (done)
              const Positioned(top: 10, left: 12, child: Text('⭐', style: TextStyle(fontSize: 30))),
          ],
        ),
      ),
    );
  }
}
