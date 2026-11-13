import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child_report.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/gamification/level_system.dart';
import '../home/sections.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final states = ref.watch(sectionStatesProvider).valueOrNull ??
        const <String, bool>{};
    final soundOn = ref.watch(soundEnabledProvider).valueOrNull ?? true;
    final voiceOn = ref.watch(voiceEnabledProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('تقدم الطفلتين', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'كل طفلة تنافس نفسها فقط، فلا توجد مقارنة بينهما.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          children.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('تعذر تحميل البيانات'),
            data: (list) => Column(
              children: [for (final c in list) _ChildReportCard(childId: c.id)],
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
          SwitchListTile(
            title: const Text('🗣️  قراءة الكلام بصوت عالٍ'),
            subtitle: const Text(
                'تقرأ التطبيق التعليمات والأسئلة للطفلة التي لا تقرأ بعد، وتشغّل تلاوة الآيات'),
            value: voiceOn,
            onChanged: (v) async {
              await ref.read(voiceServiceProvider).setEnabled(v);
              ref.invalidate(voiceEnabledProvider);
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

class _ChildReportCard extends ConsumerWidget {
  const _ChildReportCard({required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(childReportProvider(childId));
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: report.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Text('تعذر تحميل تقرير الطفلة'),
          data: (r) => _ReportBody(report: r),
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});

  final ChildReport report;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final id = report.child.id;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _EditChildDialog(name: report.child.name, age: report.child.age),
    );
    if (result == null) return;
    await ref.read(childRepositoryProvider).update(id, name: result.$1, age: result.$2);
    ref.invalidate(childrenProvider);
    ref.invalidate(selectedChildProvider);
    ref.invalidate(childReportProvider(id));
    ref.invalidate(dailyQuestsProvider(id));
    ref.invalidate(completedLessonIdsProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    final p = r.profile;
    final level = LevelSystem.info(p.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '👧 ${r.child.name} — ${r.child.age} سنوات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'تعديل الاسم والعمر',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref),
            ),
          ],
        ),
        Text('${level.icon} ${level.name} — المستوى ${p.level}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatTile(emoji: '⚡', value: '${p.xp}', label: 'XP'),
            _StatTile(emoji: '⭐', value: '${p.stars}', label: 'نجوم'),
            _StatTile(emoji: '🔥', value: '${r.activeStreak}', label: 'سلسلة أيام'),
            _StatTile(emoji: '📚', value: '${r.completedInAge}/${r.lessonsTotal}', label: 'دروس'),
            _StatTile(emoji: '🏅', value: '${r.badgesEarned}/${r.badgesTotal}', label: 'شارات'),
            _StatTile(emoji: '⏱', value: formatUsage(r.usageTodaySeconds), label: 'اليوم'),
          ],
        ),
        const SizedBox(height: 12),
        Text('آخر نشاط: ${describeLastActivity(r.lastActivity, DateTime.now())}'),
        Text('أفضل سلسلة أيام: ${p.bestStreak}'),
        Text('إجمالي وقت الاستخدام: ${formatUsage(r.usageTotalSeconds)}'),
        if (r.categories.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('تقدم الأقسام', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final c in r.categories) _CategoryBar(progress: c),
        ],
        if (r.needsReview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '🔁 تحتاج مراجعة: ${r.needsReview.map((c) => c.lesson.title).join('، ')}\n'
              'راجعوها معها بلطف وبدون ضغط.',
            ),
          ),
        ],
        const SizedBox(height: 6),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            'ما تعلّمته (${r.completed.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            if (r.completed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('لم تكمل أي درس بعد'),
              ),
            for (final c in r.completed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(c.lesson.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(c.lesson.title),
                subtitle: Text('${c.score}/${c.totalQuestions} صحيحة من أول مرة'),
                trailing: Text(c.mastered ? '✅ متقن' : '🔁 مراجعة'),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.progress});

  final CategoryProgress progress;

  @override
  Widget build(BuildContext context) {
    final match = appSections.where((s) => s.id == progress.category);
    final title = match.isEmpty
        ? progress.category
        : '${match.first.emoji} ${match.first.title}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(title)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 10,
                backgroundColor: const Color(0xFFE7EBEF),
                color: AppColors.leaf,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${progress.done}/${progress.total}'),
        ],
      ),
    );
  }
}

class _EditChildDialog extends StatefulWidget {
  const _EditChildDialog({required this.name, required this.age});

  final String name;
  final int age;

  @override
  State<_EditChildDialog> createState() => _EditChildDialogState();
}

class _EditChildDialogState extends State<_EditChildDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.name);
  late int _age = widget.age;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل بيانات الطفلة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 8),
          const Text('العمر'),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: [
              for (final a in const [3, 4, 5, 6])
                ButtonSegment<int>(value: a, label: Text('$a')),
            ],
            selected: {_age},
            onSelectionChanged: (s) => setState(() => _age = s.first),
          ),
          const SizedBox(height: 10),
          const Text(
            'تغيير العمر يغيّر الدروس والمهام المعروضة لها. التقدم السابق يبقى محفوظًا.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((name, _age));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
