import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/age_band.dart';
import '../../domain/arabic_digits.dart';
import '../../domain/badges.dart';
import '../home/sections.dart';

class _ChildStats {
  const _ChildStats(this.lessons, this.totalMinutes, this.todayMinutes, this.levels, this.badges, this.dueReviews);
  final int lessons;
  final int totalMinutes;
  final int todayMinutes;
  final Map<String, int> levels;
  final List<String> badges;
  final int dueReviews;
}

final _childStatsProvider =
    FutureProvider.autoDispose.family<_ChildStats, int>((ref, childId) async {
  final repo = ref.watch(childRepositoryProvider);
  final lessons = await repo.completedLessons(childId);
  final seconds = await repo.totalSecondsUsed(childId);
  final today =
      await ref.watch(usageRepositoryProvider).secondsOn(childId, DateTime.now());
  final levels = await ref.watch(placementRepositoryProvider).levels(childId);
  final badges = await ref.watch(badgeRepositoryProvider).earned(childId);
  final due = (await ref.watch(reviewRepositoryProvider).due(childId)).length;
  return _ChildStats(lessons, seconds ~/ 60, today ~/ 60, levels, badges, due);
});

const _trackNames = {
  'quran': 'قرآني',
  'salah': 'صلاتي',
  'maa_la_yasa': 'ما لا يسع الطفل جهله',
  'arabic': 'عربيتي',
};

String limitLabel(int m) => m == 0 ? 'بلا حد' : '${toArabicDigits(m)} دقيقة';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  late final StateController<bool> _paused;

  @override
  void initState() {
    super.initState();
    // وقت ولي الأمر في لوحته لا يُحسب من وقت الطفل.
    _paused = ref.read(usagePausedProvider.notifier);
    Future.microtask(() => _paused.state = true);
  }

  @override
  void dispose() {
    _paused.state = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    final states =
        ref.watch(sectionStatesProvider).valueOrNull ?? const <String, bool>{};
    final limit = ref.watch(dailyLimitProvider).valueOrNull ??
        SettingsRepository.defaultDailyLimitMinutes;
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            key: const Key('parents_corner_tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('قسم الوالدين'),
            subtitle: const Text('المنهج، المصادر وحالة المراجعة، الخصوصية، الرمز'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/parent/about'),
          ),
          const Divider(),
          Text('الأطفال', style: titleStyle),
          const SizedBox(height: 12),
          children.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('تعذر تحميل البيانات'),
            data: (list) => Column(
              children: [for (final c in list) _ChildCard(child: c)],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('add_child'),
            onPressed: () => context.push('/onboarding/child'),
            icon: const Icon(Icons.add),
            label: const Text('إضافة طفل'),
          ),
          const SizedBox(height: 24),
          Text('الحد اليومي للاستخدام', style: titleStyle),
          const SizedBox(height: 4),
          const Text(
              'الموصى به للصغار نصف ساعة أو أقل، والأفضل المشاركة مع الطفل'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in SettingsRepository.dailyLimitChoices)
                ChoiceChip(
                  key: Key('limit_$m'),
                  label: Text(limitLabel(m)),
                  selected: limit == m,
                  onSelected: (_) async {
                    await ref
                        .read(settingsRepositoryProvider)
                        .setDailyLimitMinutes(m);
                    ref.invalidate(dailyLimitProvider);
                    ref.read(syncServiceProvider)?.pushSettingsInBackground();
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('الأقسام الظاهرة للأطفال', style: titleStyle),
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
                ref.read(syncServiceProvider)?.pushSettingsInBackground();
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

  Future<void> _changeBand(BuildContext context, WidgetRef ref, AgeBand? b) async {
    await ref.read(childRepositoryProvider).setBand(child.id, b);
    ref.read(syncServiceProvider)?.pushChildInBackground(child.id);
    ref.invalidate(childrenProvider);
    ref.invalidate(selectedChildProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف ${child.nickname}؟'),
        content: const Text('سيُحذف ملف الطفل وتقدّمه نهائيًا.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          TextButton(
              key: const Key('confirm_delete'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(childRepositoryProvider).delete(child.id);
    final cloudId = child.cloudId;
    if (cloudId != null) {
      ref.read(syncServiceProvider)?.deleteChildInBackground(cloudId);
    }
    if (ref.read(selectedChildIdProvider) == child.id) {
      ref.read(selectedChildIdProvider.notifier).state = null;
    }
    ref.invalidate(childrenProvider);
    ref.invalidate(selectedChildProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_childStatsProvider(child.id));
    final auto = bandForAge(child.ageYears());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${child.avatarEmoji} ${child.nickname}',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  key: Key('delete_${child.id}'),
                  tooltip: 'حذف',
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text('العمر ${toArabicDigits(child.ageYears())} سنة   •   '
                'المستوى ${toArabicDigits(child.level)}   •   '
                '⭐ ${toArabicDigits(child.stars)}'),
            const SizedBox(height: 8),
            stats.when(
              loading: () => const Text('...'),
              error: (_, __) => const Text('—'),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('دروس مكتملة: ${toArabicDigits(s.lessons)}   •   '
                      'اليوم: ${toArabicDigits(s.todayMinutes)} د   •   '
                      'الإجمالي: ${toArabicDigits(s.totalMinutes)} د'),
                  if (s.dueReviews > 0) ...[
                    const SizedBox(height: 6),
                    Text('مراجعات مستحقة اليوم: ${toArabicDigits(s.dueReviews)}'),
                  ],
                  if (s.badges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('الشارات: ${[
                      for (final id in s.badges)
                        if (badgeById(id) != null)
                          '${badgeById(id)!.emoji} ${badgeById(id)!.title}'
                    ].join('  ')}'),
                  ],
                  if (s.levels.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'مستوى البداية: ${[
                        for (final e in s.levels.entries)
                          '${_trackNames[e.key] ?? e.key} ${toArabicDigits(e.value)}'
                      ].join(' • ')}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('الفئة'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: Key('band_auto_${child.id}'),
                  label: Text('تلقائي (${auto.label})'),
                  selected: child.bandOverride == null,
                  onSelected: (_) => _changeBand(context, ref, null),
                ),
                for (final b in AgeBand.values)
                  ChoiceChip(
                    key: Key('band_${b.name}_${child.id}'),
                    label: Text(b.label),
                    selected: child.bandOverride == b,
                    onSelected: (_) => _changeBand(context, ref, b),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
