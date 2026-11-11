import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/gamification/level_system.dart';
import '../../domain/gamification/quests.dart';
import '../../domain/gamification/streak.dart';
import 'sections.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final states = ref.watch(sectionStatesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'تغيير الطفلة',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            ref.read(selectedChildIdProvider.notifier).state = null;
            context.go('/');
          },
        ),
        title: const Text('نُور وفداء 🌟'),
      ),
      body: SafeArea(
        child: child.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('حدث خطأ')),
          data: (c) {
            if (c == null) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('اختاري من سيتعلم'),
                ),
              );
            }
            final enabled = states.valueOrNull ?? const <String, bool>{};
            final visible = appSections.where((s) => enabled[s.id] ?? true).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('أهلًا يا ${c.name}! 🌟', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('مغامرتك اليوم جاهزة!', style: TextStyle(fontSize: 17)),
                const SizedBox(height: 14),
                _StatusCard(child: c),
                const SizedBox(height: 14),
                _QuestsCard(child: c),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/journey'),
                    icon: const Icon(Icons.explore),
                    label: const Text('ابدئي رحلتي', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 22),
                Text('ماذا سنتعلم اليوم؟', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    for (final s in visible)
                      Material(
                        color: s.color,
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => context.push('/section/${s.id}'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.emoji, style: const TextStyle(fontSize: 44)),
                              const SizedBox(height: 8),
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// المستوى + شريط XP + النجوم + السلسلة + عدد الدروس.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gamificationProfileProvider(child.id));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF4FB3BF), AppColors.teal]),
      ),
      child: profile.when(
        loading: () => const SizedBox(
          height: 110,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (_, __) => const SizedBox(
          height: 110,
          child: Center(child: Text('تعذر تحميل تقدمك', style: TextStyle(color: Colors.white))),
        ),
        data: (p) {
          final level = LevelSystem.info(p.level);
          final streak = StreakCalculator.activeStreak(
            lastDay: p.lastActiveDay,
            today: dayKey(DateTime.now()),
            current: p.streakDays,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${level.icon} ${level.name} — المستوى ${p.level}',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: p.levelProgress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 14,
                    backgroundColor: Colors.white24,
                    color: AppColors.sun,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'باقي ${p.xpToNextLevel} XP للمستوى التالي',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Pill(text: '⭐ ${p.stars}'),
                  const SizedBox(width: 8),
                  _Pill(text: streak > 0 ? '🔥 $streak ${streak == 1 ? 'يوم' : 'أيام'}' : '🔥 ابدئي اليوم'),
                  const SizedBox(width: 8),
                  _Pill(text: '📚 ${p.totalLessons}'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// مهام اليوم: 2-3 مهام صغيرة، ومكافأة عند إكمالها كلها.
class _QuestsCard extends ConsumerWidget {
  const _QuestsCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(dailyQuestsProvider(child.id));
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: quests.when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox(height: 80, child: Center(child: Text('تعذر تحميل المهام'))),
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.allDone ? 'أكملتِ مهام اليوم! 🎉' : 'مهام اليوم',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  Text('${state.doneCount}/${state.quests.length}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              for (final q in state.quests) _QuestRow(quest: q),
              if (!state.allDone)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'أكملي المهام لتحصلي على مكافأة اليوم 🎁',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest});

  final QuestProgress quest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(quest.done ? '✅' : quest.def.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.def.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    decoration: quest.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: quest.fraction,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE7EBEF),
                    color: AppColors.leaf,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
