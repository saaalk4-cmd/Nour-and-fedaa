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
import '../../data/providers.dart';
import '../../domain/badges.dart';
import '../../domain/streak.dart';

class ChildActivity {
  const ChildActivity({this.today = 0, this.streak = 0, this.badges = const {}});
  final int today;
  final int streak;
  final Set<String> badges;
}

/// نشاط الطفل المختار: دروس اليوم، الأيام المتتالية، والشارات المكتسبة.
final childActivityProvider = FutureProvider.autoDispose<ChildActivity>((ref) async {
  final id = ref.watch(selectedChildIdProvider);
  if (id == null) return const ChildActivity();
  final done = await ref.watch(progressRepositoryProvider).completed(id);
  final dates = [for (final (_, at) in done) if (at != null) at];
  final now = DateTime.now();
  return ChildActivity(
    today: lessonsOn(dates, now),
    streak: streakDays(dates, now),
    badges: (await ref.watch(badgeRepositoryProvider).earned(id)).toSet(),
  );
});

/// رئيسية الناشئة (8–11): لوحة بهدف اليوم والتحدّيات والشارات.
class TweenHome extends StatelessWidget {
  const TweenHome({super.key, required this.child, required this.enabled});

  final Child child;
  final Map<String, bool> enabled;

  static const _dailyGoal = 3;

  @override
  Widget build(BuildContext context) {
    final visible = appSections.where((s) => enabled[s.id] ?? true).toList();

    return Scaffold(
      backgroundColor: AppColors.navy,
      bottomNavigationBar: const HomeTabs(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            Row(
              children: [
                const BrandMark(width: 60),
                Expanded(
                  child: Text('السلام عليكم يا ${child.nickname}',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
                const ParentLockButton(color: AppColors.cream),
              ],
            ),
            const SizedBox(height: 14),
            Consumer(builder: (context, ref, _) {
              final a =
                  ref.watch(childActivityProvider).valueOrNull ?? const ChildActivity();
              final done = a.today > _dailyGoal ? _dailyGoal : a.today;
              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'هدف اليوم',
                      value:
                          '${toArabicDigits(done)} من ${toArabicDigits(_dailyGoal)}',
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: done / _dailyGoal,
                          strokeWidth: 7,
                          backgroundColor: const Color(0x33DDAF68),
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'أيام متتالية',
                      value: toArabicDigits(a.streak),
                      leading: const Text('🔥', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 14),
            Consumer(
              builder: (context, ref, _) =>
                  _ChallengeCard(onTap: () => openNextLesson(context, ref)),
            ),
            const SizedBox(height: 14),
            Consumer(builder: (context, ref, _) {
              final earned =
                  ref.watch(childActivityProvider).valueOrNull?.badges ?? const {};
              return SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final b in badgeDefs)
                      Tooltip(
                        message: b.title,
                        child: Container(
                          key: Key('badge_${b.id}'),
                          width: 56,
                          margin: const EdgeInsetsDirectional.only(end: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16204A),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppColors.gold.withValues(
                                    alpha: earned.contains(b.id) ? 1 : 0.4)),
                          ),
                          alignment: Alignment.center,
                          child: Text(earned.contains(b.id) ? b.emoji : '🔒',
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                for (final s in visible)
                  SectionCard(
                    emoji: s.emoji,
                    title: s.title,
                    color: AppColors.cream,
                    soon: s.soon,
                    emojiSize: 26,
                    titleSize: 16,
                    onTap: () => context.push('/section/${s.id}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.leading,
  });

  final String title;
  final String value;
  final Widget leading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16204A),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(value,
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w800,
                            fontSize: 22)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Text('🎯', style: TextStyle(fontSize: 44)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تحدّي اليوم',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('أكمل درسًا واحدًا واكسب نجمة جديدة',
                          style:
                              TextStyle(color: AppColors.navy, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
