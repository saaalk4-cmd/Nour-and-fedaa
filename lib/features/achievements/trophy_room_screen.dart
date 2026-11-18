import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_on_open.dart';
import '../../data/providers.dart';
import '../../domain/gamification/achievements.dart';

/// غرفة الجوائز: مجموعة الشارات. المقفل يُعرض كدعوة لطيفة وليس كفشل.
class TrophyRoomScreen extends ConsumerWidget {
  const TrophyRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    return SpeakOnOpen(
      text: 'هذه إنجازاتي',
      child: Scaffold(
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
                    childAspectRatio: 0.95,
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
    ));
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
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFC58BF0), Color(0xFF8E6BD1)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x558E6BD1), blurRadius: 16, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 72)),
          Text('غرفة الجوائز', style: AppText.display(32, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            count == 0 ? 'أول شارة تنتظرك يا $name!' : 'جمعتِ $count من $total شارات يا $name!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 16,
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
    return PopTap(
      haptic: false,
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(earned ? '${def.title}: مبروك! ✨' : def.description)));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: earned
              ? const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.white, Color(0xFFFFF1C7)],
                )
              : null,
          color: earned ? null : const Color(0xFFE3E8ED),
          border: earned ? Border.all(color: AppColors.sun, width: 3) : null,
          boxShadow: earned
              ? const [BoxShadow(color: Color(0x44F4B942), blurRadius: 14, offset: Offset(0, 6))]
              : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: earned ? 1 : 0.3,
                  child: Text(def.emoji, style: const TextStyle(fontSize: 58)),
                ),
                if (!earned) const Icon(Icons.lock_rounded, size: 26, color: Color(0xFF7A8794)),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                def.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(19, color: earned ? AppColors.ink : const Color(0xFF7A8794)),
              ),
            ),
            if (earned)
              const Text('⭐ مبروك', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.leaf)),
          ],
        ),
      ),
    );
  }
}
