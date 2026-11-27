import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/age_band.dart';
import '../../domain/arabic_digits.dart';
import '../../domain/badges.dart';
import '../home/sections.dart';

const _weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

class ChildReport {
  const ChildReport({
    required this.child,
    required this.days,
    required this.bySection,
    required this.recent,
    required this.badges,
  });

  final Child child;

  /// (اليوم، الدقائق) لآخر ٧ أيام.
  final List<(DateTime, int)> days;

  /// اسم القسم ← عدد الدروس المكتملة فيه.
  final Map<String, int> bySection;

  /// (عنوان الدرس، وقت الإتمام) الأحدث أولًا، بحد أقصى ٥.
  final List<(String, DateTime?)> recent;
  final List<BadgeDef> badges;

  int get weekMinutes => days.fold(0, (s, d) => s + d.$2);
}

final childReportProvider =
    FutureProvider.autoDispose.family<ChildReport, int>((ref, id) async {
  final child = await ref.watch(childRepositoryProvider).byId(id);
  if (child == null) throw StateError('الطفل غير موجود');
  final usage = await ref.watch(usageRepositoryProvider).lastDays(id, 7);
  final done = await ref.watch(progressRepositoryProvider).completed(id);
  final lessons = ref.watch(lessonRepositoryProvider);
  final bySection = <String, int>{};
  final recent = <(String, DateTime?)>[];
  for (final (lessonId, at) in done) {
    try {
      final l = await lessons.byId(lessonId);
      final name = findSection(l.section ?? '')?.title ?? 'أخرى';
      bySection[name] = (bySection[name] ?? 0) + 1;
      if (recent.length < 5) recent.add((l.title, at));
    } catch (_) {/* درس لم يعد موجودًا */}
  }
  final badges = [
    for (final b in await ref.watch(badgeRepositoryProvider).earned(id))
      if (badgeById(b) != null) badgeById(b)!
  ];
  return ChildReport(
    child: child,
    days: [for (final (d, s) in usage) (d, s ~/ 60)],
    bySection: bySection,
    recent: recent,
    badges: badges,
  );
});

/// تقرير الأسبوع لولي الأمر: بلا درجات ولا مقارنة بأطفال آخرين.
class ChildReportScreen extends ConsumerWidget {
  const ChildReportScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(childReportProvider(childId));
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الأسبوع')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر تحميل التقرير')),
        data: (r) => _body(context, ref, r),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ChildReport r) {
    final t = Theme.of(context).textTheme;
    final maxMin = r.days.fold(1, (m, d) => d.$2 > m ? d.$2 : m);
    final hasCheck = r.child.band() != AgeBand.buraem;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('${r.child.avatarEmoji} ${r.child.nickname}', style: t.headlineSmall),
        const SizedBox(height: 16),
        Text('وقت الاستخدام: ${toArabicDigits(r.weekMinutes)} دقيقة هذا الأسبوع',
            style: t.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (d, m) in r.days)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(toArabicDigits(m), style: t.labelSmall),
                      const SizedBox(height: 2),
                      Container(
                        height: 90 * m / maxMin + 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(_weekdays[d.weekday - 1],
                            style: t.labelSmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        Text('ما تعلّمه حتى الآن', style: t.titleMedium),
        const SizedBox(height: 8),
        if (r.bySection.isEmpty)
          const Text('لم يكمل دروسًا بعد')
        else
          for (final e in r.bySection.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text('${toArabicDigits(e.value)} درس'),
            ),
        if (r.recent.isNotEmpty) ...[
          const Divider(height: 32),
          Text('آخر الدروس', style: t.titleMedium),
          for (final (title, at) in r.recent)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_rounded, color: AppColors.gold),
              title: Text(title),
              trailing: at == null
                  ? null
                  : Text(
                      '${toArabicDigits(at.day)}/${toArabicDigits(at.month)}'),
            ),
        ],
        if (r.badges.isNotEmpty) ...[
          const Divider(height: 32),
          Text('الشارات', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            for (final b in r.badges) Chip(label: Text('${b.emoji} ${b.title}')),
          ]),
        ],
        if (hasCheck) ...[
          const Divider(height: 32),
          OutlinedButton.icon(
            key: const Key('retake_check'),
            onPressed: () {
              ref.read(selectedChildIdProvider.notifier).state = r.child.id;
              context.push('/onboarding/check?return=/parent/dashboard');
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة اختبار المستوى'),
          ),
        ],
      ],
    );
  }
}
