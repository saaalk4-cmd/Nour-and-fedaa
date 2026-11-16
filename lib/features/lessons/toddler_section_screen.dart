import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/section_tile.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// قسم الصغيرات (3–4 سنوات): بطاقات صور كبيرة، بلا نصوص طويلة ولا مصادر.
/// الضغط على البطاقة يفتح الدرس بواجهة «صورة + صوت + لمس».
const _palette = <Color>[
  Color(0xFF2A9D8F),
  Color(0xFFE76F8B),
  Color(0xFF6C7BD9),
  Color(0xFFE08E45),
  Color(0xFF4FAF8E),
  Color(0xFF58A6D8),
];

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
              for (var i = 0; i < mine.length; i++)
                _PictureCard(
                  lesson: mine[i],
                  done: done.contains(mine[i].id),
                  color: _palette[i % _palette.length],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({required this.lesson, required this.done, required this.color});

  final Lesson lesson;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      emoji: lesson.emoji,
      title: lesson.title,
      color: color,
      emojiSize: 60,
      badge: done ? '⭐' : null,
      onTap: () => context.push('/lesson/${lesson.id}'),
    );
  }
}
