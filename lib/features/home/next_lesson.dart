import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/lesson.dart';

/// ترتيب الأقسام عند اختيار «الدرس التالي».
const nextLessonSectionOrder = [
  SectionIds.arabic,
  SectionIds.prayer,
  SectionIds.aqeedah,
  SectionIds.quran,
  SectionIds.akhlaq,
  SectionIds.adhkar,
];

class NextLesson {
  const NextLesson({this.lesson, required this.done, required this.total});

  /// أول درس لم يُكمَل بعد (null = أكمل كل المتاح).
  final Lesson? lesson;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

/// الدرس التالي للطفل المختار في فئته، متجاوزًا الأقسام التي أوقفها ولي الأمر.
final nextLessonProvider = FutureProvider.autoDispose<NextLesson>((ref) async {
  final child = await ref.watch(selectedChildProvider.future);
  if (child == null) return const NextLesson(done: 0, total: 0);
  final enabled = await ref.watch(sectionStatesProvider.future);
  final lessons = ref.watch(lessonRepositoryProvider);
  final progress = ref.watch(progressRepositoryProvider);
  final placement = await ref.watch(placementRepositoryProvider).levels(child.id);
  Lesson? next;
  var done = 0, total = 0;
  for (final section in nextLessonSectionOrder) {
    if (enabled[section] == false) continue;
    final pending = <Lesson>[];
    for (final l in await lessons.bySection(section, child.band())) {
      total++;
      if (await progress.isDone(child.id, l.id)) {
        done++;
      } else {
        pending.add(l);
      }
    }
    if (next != null || pending.isEmpty) continue;
    next = pickByPlacement(pending, placement);
  }
  return NextLesson(lesson: next, done: done, total: total);
});

/// من دروس القسم غير المكتملة: أول درس بمستوى ≥ مستوى الطفل في مساره
/// (حسب اختبار المستوى)، وإلا أول درس غير مكتمل.
Lesson pickByPlacement(List<Lesson> pending, Map<String, int> placement) {
  final track = pending.first.placementTrack;
  final start = track == null ? 1 : (placement[track] ?? 1);
  return pending.firstWhere((l) => l.level >= start, orElse: () => pending.first);
}

/// يفتح الدرس التالي، أو قسم العربية إن اكتمل كل شيء.
Future<void> openNextLesson(BuildContext context, WidgetRef ref) async {
  final next = await ref.read(nextLessonProvider.future);
  if (!context.mounted) return;
  final id = next.lesson?.id;
  await context.push(id == null ? '/section/${SectionIds.arabic}' : '/lesson/$id');
  ref.invalidate(nextLessonProvider);
}
