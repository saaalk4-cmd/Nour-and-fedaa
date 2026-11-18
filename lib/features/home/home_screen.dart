import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/pop_tap.dart';
import '../../core/design/section_tile.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_on_open.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/gamification/achievements.dart';
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
          icon: const Icon(Icons.swap_horiz_rounded, size: 30),
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
            final little = ContentLevel.forAge(c.age).pictureOnly;
            final enabled = states.valueOrNull ?? const <String, bool>{};
            final visible = appSections.where((s) => enabled[s.id] ?? true).toList();
            return SpeakOnOpen(
              text: 'أهلًا يا ${c.name}! ماذا نتعلم اليوم؟',
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _Greeting(name: c.name, little: little),
                const SizedBox(height: 16),
                _StatusCard(child: c, compact: little),
                const SizedBox(height: 16),
                _JourneyHero(little: little),
                if (!little) ...[
                  const SizedBox(height: 16),
                  _QuestsCard(child: c),
                ],
                _LatestBadge(childId: c.id),
                const SizedBox(height: 24),
                Text('ماذا سنتعلم اليوم؟', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: little ? 0.95 : 1.0,
                  children: [
                    for (final s in visible)
                      SectionTile(
                        emoji: s.emoji,
                        title: s.title,
                        color: s.color,
                        emojiSize: little ? 58 : 46,
                        onTap: () => context.push('/section/${s.id}'),
                      ),
                  ],
                ),
              ],
            ));
          },
        ),
      ),
    );
  }
}

/// لَمعة + تحية الطفلة داخل فقاعة كلام.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.little});

  final String name;
  final bool little;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.75),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Mascot(size: little ? 100 : 88),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أهلًا يا $name! 🌟', style: AppText.display(little ? 30 : 26)),
                if (!little) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'أنا لَمعة، ومغامرتك اليوم جاهزة!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// زر «رحلتي اليوم»: بطاقة كبيرة بتدرّج دافئ وأيقونة تتمايل.
class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.little});

  final bool little;

  @override
  Widget build(BuildContext context) {
    return PopTap(
      onTap: () => context.push('/today'),
      child: Container(
        height: little ? 150 : 128,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFB84D), Color(0xFFF2709C)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x55F2709C), blurRadius: 18, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            const _Bob(child: Text('🧭', style: TextStyle(fontSize: 64))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رحلتي اليوم', style: AppText.display(little ? 38 : 34, color: Colors.white)),
                  if (!little)
                    const Text(
                      'مغامرات قصيرة وممتعة',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, size: 46, color: Color(0xFFF2709C)),
            ),
          ],
        ),
      ),
    );
  }
}

/// حركة صعود وهبوط لطيفة للأيقونات.
class _Bob extends StatefulWidget {
  const _Bob({required this.child});

  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// المستوى + شريط XP + النجوم + السلسلة + عدد الدروس.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.child, this.compact = false});

  final Child child;

  /// للصغيرات: أيقونات وأرقام فقط بلا نصوص شرح.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gamificationProfileProvider(child.id));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF4FB3BF), AppColors.teal]),
        boxShadow: const [BoxShadow(color: Color(0x332A9D8F), blurRadius: 14, offset: Offset(0, 8))],
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
          if (compact) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Pill(text: '⭐ ${p.stars}', big: true),
                _Pill(text: '🔥 $streak', big: true),
                _Pill(text: '📚 ${p.totalLessons}', big: true),
              ],
            );
          }
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
  const _Pill({required this.text, this.big = false});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 16 : 12, vertical: big ? 10 : 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: big ? 24 : 15, fontWeight: FontWeight.w800),
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

/// «آخر إنجاز»: أحدث شارة حصلت عليها الطفلة (لا تظهر إن لم تحصل على شيء بعد).
class _LatestBadge extends ConsumerWidget {
  const _LatestBadge({required this.childId});
  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedBadgesProvider(childId)).valueOrNull;
    if (earned == null || earned.isEmpty) return const SizedBox.shrink();
    final ids = earned.keys.toList()
      ..sort((a, b) => earned[b]!.compareTo(earned[a]!));
    final def = Achievements.byId(ids.first);
    if (def == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ListTile(
          leading: Text(def.emoji, style: const TextStyle(fontSize: 34)),
          title: const Text('آخر إنجاز', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(def.title),
        ),
      ),
    );
  }
}
