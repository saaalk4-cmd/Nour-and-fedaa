import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/age_band.dart';
import '../../domain/lesson.dart';
import 'sections.dart';

/// شاشة القسم: تعرض دروسه للفئة الحالية، أو «قريبًا» إن لم توجد دروس بعد.
class SectionScreen extends ConsumerWidget {
  const SectionScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = findSection(sectionId);
    final child = ref.watch(selectedChildProvider).valueOrNull;
    final lessons = child == null
        ? const AsyncValue<List<Lesson>>.data([])
        : ref.watch(
            sectionLessonsProvider((section: sectionId, band: child.band())));
    return Scaffold(
      // البراعم لا يقرؤون: نعرض أيقونة القسم بدل اسمه.
      appBar: AppBar(
        title: child?.band() == AgeBand.buraem
            ? Semantics(
                label: s?.title,
                child: ExcludeSemantics(
                  child: Text(s?.emoji ?? '🌙',
                      style: const TextStyle(fontSize: 32)),
                ),
              )
            : Text(s?.title ?? 'براق'),
      ),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر تحميل الدروس')),
        data: (list) => list.isEmpty
            ? _soon(context, s)
            : _LessonList(lessons: list, childId: child?.id, color: s?.color),
      ),
    );
  }

  Widget _soon(BuildContext context, AppSection? s) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s?.emoji ?? '🌙', style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text('قريبًا إن شاء الله',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
}

final _doneProvider = FutureProvider.autoDispose
    .family<bool, ({int childId, String lessonId})>(
  (ref, k) => ref.watch(progressRepositoryProvider).isDone(k.childId, k.lessonId),
);

class _LessonList extends ConsumerWidget {
  const _LessonList({required this.lessons, required this.childId, this.color});

  final List<Lesson> lessons;
  final int? childId;
  final Color? color;

  bool _isDone(WidgetRef ref, Lesson l) =>
      childId != null &&
      (ref
              .watch(_doneProvider((childId: childId!, lessonId: l.id)))
              .valueOrNull ??
          false);

  Future<void> _open(BuildContext context, WidgetRef ref, Lesson l) async {
    await context.push('/lesson/${l.id}');
    if (childId != null) {
      ref.invalidate(_doneProvider((childId: childId!, lessonId: l.id)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final l in lessons)
          Card(
            color: color,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: l.textFreeForChild
                ? _IconTile(
                    lesson: l,
                    done: _isDone(ref, l),
                    onTap: () => _open(context, ref, l),
                  )
                : ListTile(
                    key: Key('lesson_${l.id}'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    title: Text(
                      l.subtitle == null ? l.title : '${l.title} – ${l.subtitle}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    leading:
                        const Icon(Icons.play_circle_fill_rounded, size: 48),
                    trailing: _isDone(ref, l)
                        ? const Icon(Icons.star_rounded,
                            color: Color(0xFFDDAF68), size: 36)
                        : null,
                    onTap: () => _open(context, ref, l),
                  ),
          ),
      ],
    );
  }
}

/// بلاطة أيقونة كبيرة بلا نص مكتوب (للبراعم). الاسم متاح لقارئ الشاشة فقط.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.lesson, required this.done, required this.onTap});

  final Lesson lesson;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: lesson.title,
      child: InkWell(
        key: Key('lesson_${lesson.id}'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ExcludeSemantics(
                child: Text(lesson.icon ?? '🎧',
                    style: const TextStyle(fontSize: 64)),
              ),
              if (done)
                const PositionedDirectional(
                  end: 16,
                  child: Icon(Icons.star_rounded,
                      color: Color(0xFFDDAF68), size: 40),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
