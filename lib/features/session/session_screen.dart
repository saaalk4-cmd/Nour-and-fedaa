import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/arabic_digits.dart';

/// شاشة الحصة: دروسها بلاطات كبيرة بالترتيب، وعلامة ✓ لما اكتمل.
/// بلا قراءة للبراعم: الرقم والوحدة يظهران صغيرين لولي الأمر فقط.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sessionByNumberProvider(number));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(backgroundColor: AppColors.cream),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر تحميل الحصة')),
        data: (d) {
          if (d == null) return const Center(child: Text('لا توجد حصة'));
          final s = d.session;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'الحصة ${toArabicDigits(s.n)} • ${s.unitTitle}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < s.lessons.length; i++)
                  _LessonTile(
                    key: Key('session_lesson_$i'),
                    lessonId: s.lessons[i],
                    done: d.done.contains(s.lessons[i]),
                    // الدرس التالي يُفتح بعد إتمام الذي قبله.
                    locked: i > 0 && !d.done.contains(s.lessons[i - 1]),
                    onTap: () async {
                      await context.push('/lesson/${s.lessons[i]}');
                      ref.invalidate(sessionByNumberProvider(number));
                      ref.invalidate(todaySessionProvider);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LessonTile extends ConsumerWidget {
  const _LessonTile({
    super.key,
    required this.lessonId,
    required this.done,
    required this.locked,
    required this.onTap,
  });

  final String lessonId;
  final bool done;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: done
            ? const Color(0xFFCFE8C9)
            : locked
                ? Colors.grey.shade300
                : Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: locked ? null : onTap,
          child: SizedBox(
            height: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lesson?.icon ?? '⭐', style: const TextStyle(fontSize: 90)),
                const SizedBox(width: 24),
                Text(done ? '✅' : (locked ? '🔒' : '▶️'),
                    style: const TextStyle(fontSize: 48)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
