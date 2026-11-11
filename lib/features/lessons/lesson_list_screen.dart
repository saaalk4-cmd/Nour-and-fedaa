import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// قائمة دروس «أتعلم»: تُعرض للطفلة المختارة حسب عمرها فقط.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final lessons = ref.watch(lessonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('أتعلم 🧠')),
      body: child.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('حدث خطأ')),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('اختاري طفلة أولًا'));
          }
          final done = ref.watch(completedLessonIdsProvider(c.id)).valueOrNull ??
              const <String>{};
          return lessons.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('تعذر تحميل الدروس')),
            data: (all) {
              final mine = all.where((l) => l.fitsAge(c.age)).toList();
              if (mine.isEmpty) {
                return const Center(child: Text('دروس جديدة قريبًا 🌟'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: mine.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _LessonCard(
                  lesson: mine[i],
                  done: done.contains(mine[i].id),
                  little: c.ageGroup == AgeGroup.early,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.done,
    required this.little,
  });

  final Lesson lesson;
  final bool done;
  final bool little;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => context.push('/lesson/${lesson.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Text(lesson.emoji, style: TextStyle(fontSize: little ? 56 : 46)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done ? 'أكملتِه ✨ يمكنك مراجعته' : 'درس قصير وممتع',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              done
                  ? const Text('✅', style: TextStyle(fontSize: 30))
                  : const Icon(
                      Icons.play_circle_fill,
                      size: 40,
                      color: AppColors.teal,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
