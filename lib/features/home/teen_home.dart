import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/child.dart';
import '../../domain/arabic_digits.dart';
import 'home_shared.dart';
import 'next_lesson.dart';
import 'sections.dart';

/// رئيسية المراهقين (12–14): بسيطة وراقية، قوائم ونسب بلا رسوم طفولية.
class TeenHome extends StatelessWidget {
  const TeenHome({super.key, required this.child, required this.enabled});

  final Child child;
  final Map<String, bool> enabled;

  @override
  Widget build(BuildContext context) {
    final tracks =
        appSections.where((s) => !s.soon && (enabled[s.id] ?? true)).toList();

    return Scaffold(
      backgroundColor: AppColors.navy,
      bottomNavigationBar: const HomeTabs(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            Row(
              children: [
                const BrandMark(width: 66),
                const Spacer(),
                const ParentLockButton(color: AppColors.cream),
              ],
            ),
            const SizedBox(height: 8),
            Text('السلام عليكم يا ${child.nickname}',
                style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Consumer(builder: (context, ref, _) {
              final next = ref.watch(nextLessonProvider).valueOrNull;
              final status = next == null || next.done == 0
                  ? 'لم تبدأ بعد'
                  : next.lesson == null
                      ? 'أكملت كل الدروس المتاحة'
                      : 'التالي: ${next.lesson!.title}';
              return _Card(
                onTap: () => openNextLesson(context, ref),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('درسك التالي',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: next?.fraction ?? 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFEBDDBE),
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 8),
                    Text(status,
                        key: const Key('teen_next_status'),
                        style: TextStyle(
                            color: AppColors.navy.withValues(alpha: 0.7))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 22),
            const Text('مساراتي',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final t in tracks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/section/${t.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(t.emoji,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22, color: AppColors.cream)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      color: AppColors.cream,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(
                                value: 0,
                                minHeight: 6,
                                backgroundColor: Color(0x33DDAF68),
                                color: AppColors.gold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${toArabicDigits(0)}٪',
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _Card(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريبًا إن شاء الله')),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: AppColors.navy),
                  SizedBox(width: 12),
                  Text('اسأل ولي أمرك',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      );
}
