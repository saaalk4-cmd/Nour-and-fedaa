import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../home/sections.dart';

class _ChildStats {
  const _ChildStats(this.lessons, this.minutes);
  final int lessons;
  final int minutes;
}

final _childStatsProvider =
    FutureProvider.family<_ChildStats, int>((ref, childId) async {
  final repo = ref.watch(childRepositoryProvider);
  final lessons = await repo.completedLessons(childId);
  final seconds = await repo.totalSecondsUsed(childId);
  return _ChildStats(lessons, seconds ~/ 60);
});

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final states = ref.watch(sectionStatesProvider).valueOrNull ??
        const <String, bool>{};
    final soundOn = ref.watch(soundEnabledProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('تقدم الطفلتين',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          children.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('تعذر تحميل البيانات'),
            data: (list) => Column(
              children: [for (final c in list) _ChildCard(child: c)],
            ),
          ),
          const SizedBox(height: 24),
          Text('الصوت', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: const Text('🔊  المؤثرات الصوتية'),
            subtitle: const Text('أصوات النجاح والمكافآت'),
            value: soundOn,
            onChanged: (v) async {
              await ref.read(soundServiceProvider).setEnabled(v);
              ref.invalidate(soundEnabledProvider);
            },
          ),
          const SizedBox(height: 16),
          Text('الأقسام الظاهرة للطفلتين',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final s in appSections)
            SwitchListTile(
              title: Text('${s.emoji}  ${s.title}'),
              value: states[s.id] ?? true,
              onChanged: (v) async {
                await ref
                    .read(settingsRepositoryProvider)
                    .setSectionEnabled(s.id, v);
                ref.invalidate(sectionStatesProvider);
              },
            ),
        ],
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_childStatsProvider(child.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👧 ${child.name} — ${child.age} سنوات',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('المستوى ${child.level}   •   ⭐ ${child.stars}   •   '
                'النقاط ${child.points}'),
            const SizedBox(height: 4),
            stats.when(
              loading: () => const Text('...'),
              error: (_, __) => const Text('—'),
              data: (s) => Text(
                  'دروس مكتملة: ${s.lessons}   •   مدة الاستخدام: ${s.minutes} دقيقة'),
            ),
          ],
        ),
      ),
    );
  }
}
