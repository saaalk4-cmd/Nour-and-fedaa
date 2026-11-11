import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';
import '../../data/repositories/gamification_repository.dart';

final gamificationRepositoryProvider = Provider((_) => GamificationRepository());
final gamificationProfileProvider = FutureProvider.family((ref, int childId) {
  return ref.watch(gamificationRepositoryProvider).profile(childId);
});

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    return child.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('حدث خطأ'))),
      data: (c) {
        if (c == null) return const Scaffold(body: Center(child: Text('اختاري طفلة أولًا')));
        final profile = ref.watch(gamificationProfileProvider(c.id));
        return Scaffold(
          appBar: AppBar(title: const Text('رحلتي 🧭')),
          body: profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('تعذر تحميل الرحلة')),
            data: (p) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(colors: [Color(0xFF4FB3BF), Color(0xFF2A9D8F)]),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('أهلًا يا ${c.name}! 🌟', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('رحلتك مستمرة — المستوى ${p.level}', style: const TextStyle(color: Colors.white, fontSize: 17)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(value: p.levelProgress, minHeight: 14, backgroundColor: Colors.white24),
                    ),
                    const SizedBox(height: 8),
                    Text('${p.xp} XP — خطوة جديدة كل يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _Stat(icon: '⭐', value: p.stars.toString(), label: 'نجوم')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(icon: '🔥', value: p.streakDays.toString(), label: 'أيام')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(icon: '📚', value: p.totalLessons.toString(), label: 'دروس')),
                ]),
                const SizedBox(height: 24),
                Text('مغامرتك اليوم', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      const Text('🎯', style: TextStyle(fontSize: 42)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('مهمة اليوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const Text('اختاري نشاطًا صغيرًا وابدئي التقدم'),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: () => context.push('/section/learn'), child: const Text('ابدئي الآن')),
                      ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Text('محطات الرحلة', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const _Node('1', '🌱', 'بداية الرحلة', 'أنت هنا', true),
                _Node('2', '📚', 'حديقة المعرفة', 'اقتربي منها', p.level >= 2),
                _Node('3', '🌙', 'وادي الأذكار', 'سيفتح مع تقدمك', p.level >= 3),
                _Node('4', '🕌', 'مدينة الصلاة', 'رحلة جديدة تنتظرك', p.level >= 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final String icon, value, label;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 27)),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label),
      ]),
    ),
  );
}

class _Node extends StatelessWidget {
  const _Node(this.number, this.icon, this.title, this.subtitle, this.unlocked);
  final String number, icon, title, subtitle;
  final bool unlocked;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: unlocked ? Colors.white : const Color(0xFFE7EBEF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ListTile(
      leading: CircleAvatar(child: Text(number)),
      title: Text('$icon  $title', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Icon(unlocked ? Icons.arrow_forward_ios : Icons.lock_outline, size: 20),
    ),
  );
}
