import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/gamification/achievements.dart';

/// غرفة الجوائز: مجموعة الشارات. المقفل يُعرض كدعوة لطيفة وليس كفشل.
class TrophyRoomScreen extends ConsumerWidget {
  const TrophyRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('إنجازاتي 🌟')),
      body: child.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('حدث خطأ')),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('اختاري طفلة أولًا'));
          }
          final earnedAsync = ref.watch(earnedBadgesProvider(c.id));
          return earnedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('تعذر تحميل الإنجازات')),
            data: (earned) {
              final total = Achievements.earnable.length;
              final count = Achievements.earnable.where((a) => earned.containsKey(a.id)).length;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Header(name: c.name, count: count, total: total),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                    children: [
                      for (final a in Achievements.all)
                        _BadgeCard(def: a, earned: earned.containsKey(a.id)),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.count, required this.total});

  final String name;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFFB57EDC), Color(0xFF8E6BD1)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 غرفة الجوائز',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            count == 0
                ? 'أول شارة تنتظرك يا $name!'
                : 'جمعتِ $count من $total شارات يا $name!',
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
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
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.def, required this.earned});

  final AchievementDef def;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: earned ? Colors.white : const Color(0xFFE7EBEF),
      elevation: earned ? 2 : 0,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: earned ? 1 : 0.35,
              child: Text(def.emoji, style: const TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: 8),
            Text(
              def.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: earned ? AppColors.ink : const Color(0xFF7A8794),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              earned ? 'مبروك! ✨' : def.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: earned ? AppColors.leaf : const Color(0xFF7A8794),
              ),
            ),
            if (!earned) ...[
              const SizedBox(height: 4),
              const Icon(Icons.lock_outline, size: 18, color: Color(0xFF9AA5B1)),
            ],
          ],
        ),
      ),
    );
  }
}
