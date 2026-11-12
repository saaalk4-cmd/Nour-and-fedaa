import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/lesson.dart';
import '../../data/content/lesson_progression.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// قائمة دروس «أتعلم»: تُعرض للطفلة المختارة حسب عمرها فقط، بتدرّج مناسب لها.
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
              final next = LessonProgression.next(mine, done);
              final little = c.ageGroup == AgeGroup.early;
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: mine.length,
                separatorBuilder: (_, __) => SizedBox(height: little ? 18 : 14),
                itemBuilder: (context, i) {
                  final l = mine[i];
                  final unlocked = LessonProgression.isUnlocked(l, mine, done);
                  final pre = unlocked ? null : LessonProgression.prerequisite(l, mine);
                  return _LessonCard(
                    lesson: l,
                    done: done.contains(l.id),
                    unlocked: unlocked,
                    isNext: next?.id == l.id,
                    little: little,
                    lockedHint: pre == null
                        ? 'قريبًا ستصلين هنا!'
                        : 'أكملي «${pre.title}» أولًا — قريبًا ستصلين هنا!',
                  );
                },
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
    required this.unlocked,
    required this.isNext,
    required this.little,
    required this.lockedHint,
  });

  final Lesson lesson;
  final bool done;
  final bool unlocked;
  final bool isNext;
  final bool little;
  final String lockedHint;

  @override
  Widget build(BuildContext context) {
    final String subtitle;
    if (!unlocked) {
      subtitle = lockedHint;
    } else if (done) {
      subtitle = 'أكملتِه ✨ يمكنك مراجعته';
    } else if (isNext) {
      subtitle = '✨ الدرس التالي لكِ';
    } else {
      subtitle = 'درس قصير وممتع';
    }

    return Material(
      color: unlocked ? Colors.white : const Color(0xFFE7EBEF),
      elevation: unlocked ? 1 : 0,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          if (unlocked) {
            context.push('/lesson/${lesson.id}');
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(lockedHint)));
          }
        },
        child: Container(
          padding: EdgeInsets.all(little ? 22 : 18),
          decoration: isNext
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.sun, width: 3),
                )
              : null,
          child: Row(
            children: [
              Opacity(
                opacity: unlocked ? 1 : 0.35,
                child: Text(lesson.emoji, style: TextStyle(fontSize: little ? 64 : 46)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: little ? 24 : 21,
                        fontWeight: FontWeight.w800,
                        color: unlocked ? AppColors.ink : const Color(0xFF7A8794),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 15)),
                    if (!little && unlocked) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${'⭐' * lesson.difficulty} المستوى ${lesson.difficulty}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (!unlocked)
                const Icon(Icons.lock_outline, size: 30, color: Color(0xFF9AA5B1))
              else if (done)
                const Text('✅', style: TextStyle(fontSize: 30))
              else
                const Icon(Icons.play_circle_fill, size: 44, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}
