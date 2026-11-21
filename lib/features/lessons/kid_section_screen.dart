import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

const _palette = <Color>[
  Color(0xFF2A9D8F),
  Color(0xFFE76F8B),
  Color(0xFF6C7BD9),
  Color(0xFFE08E45),
  Color(0xFF4FAF8E),
  Color(0xFF58A6D8),
];

final _weekId = RegExp(r'^w(\d+)_');
int weekOf(Lesson l) => int.tryParse(_weekId.firstMatch(l.id)?.group(1) ?? '') ?? 0;

/// الاسم كما يُنطق: بلا رموز تعبيرية.
String spokenTitle(String title) => title
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2190}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]', unicode: true), '')
    .trim();

/// قسم فداء (5 سنوات): بطاقات صور كبيرة ناطقة بدل القوائم النصية.
/// تُنطق عبارة القسم عند الفتح، وعنوان الدرس عند الضغط ثم يبدأ الدرس الصوتي.
/// لا يُنطق هنا أي نص آية أو حديث: العنوان فقط، وعبر [Lesson.spokenText].
class KidSectionScreen extends ConsumerStatefulWidget {
  const KidSectionScreen({
    super.key,
    required this.category,
    required this.title,
    required this.child,
    this.parentView,
    this.week,
  });

  final String category;
  final String title;
  final Child child;

  /// شاشة النص الكاملة (المصدر والراوي والرقم) للأهل: بالضغط المطوّل على 📋.
  final WidgetBuilder? parentView;

  /// في «أتعلم»: رقم الأسبوع المعروض (null = مجلدات الأسابيع).
  final int? week;

  @override
  ConsumerState<KidSectionScreen> createState() => _KidSectionScreenState();
}

class _KidSectionScreenState extends ConsumerState<KidSectionScreen> {
  bool _busy = false;

  // اسم القسم يُقال عند الضغط عليه قبل الفتح (في كل مكان)، فلا نكرره هنا.

  /// شاشة الأهل محمية بنفس رمز PIN للوحة ولي الأمر (إن وُجد).
  Future<void> _parentView() async {
    final repo = ref.read(settingsRepositoryProvider);
    final nav = Navigator.of(context);
    var ok = !await repo.hasPin();
    if (!ok && mounted) {
      final ctl = TextEditingController();
      final pin = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('للأهل: أدخل رمز PIN'),
          content: TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('تأكيد'))],
        ),
      );
      ok = pin != null && await repo.verifyPin(pin);
    }
    if (ok && mounted) await nav.push(MaterialPageRoute<void>(builder: widget.parentView!));
  }

  Future<void> _open(Lesson l) async {
    if (_busy) return;
    _busy = true;
    try {
      // اسم الدرس يُقال بصوت عالٍ عند الضغط على البطاقة، ثم يُفتح الدرس (ويقول اسمه مرة ثانية أول ما يفتح).
      final voice = ref.read(voiceServiceProvider);
      final name = l.spokenText(spokenTitle(l.title), step: true);
      if (name != null) {
        await voice.sayAndWait(name, max: const Duration(seconds: 6));
      } else {
        await voice.stop();
      }
      if (mounted) await context.push('/lesson/${l.id}');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(widget.child.id)).valueOrNull ?? const <String>{};
    return KidScaffold(
      title: spokenTitle(widget.title),
      background: SectionLook.of(widget.category).background,
      onBack: () => context.canPop() ? context.pop() : context.go('/world'),
      actions: [
        if (widget.parentView != null)
          GlossyButton(color: const Color(0xFF8D99AE), label: 'للأهل', icon: Icons.assignment_rounded, size: 52, onTap: _parentView),
      ],
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل الدروس')),
        data: (all) {
          var mine = all.where((l) => l.category == widget.category && l.fitsAge(widget.child.age)).toList();
          if (mine.isEmpty) {
            return const Center(child: Text('🌟', style: TextStyle(fontSize: 96)));
          }
          if (widget.category == 'learn' && widget.week == null) {
            return _weekFolders(mine, done);
          }
          if (widget.week != null) mine = mine.where((l) => weekOf(l) == widget.week).toList();
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: mine.length,
            itemBuilder: (_, i) => WorldTile(
              emoji: mine[i].emoji,
              title: spokenTitle(mine[i].title),
              color: _palette[i % _palette.length],
              emojiSize: 60,
              badge: done.contains(mine[i].id),
              onTap: () => _open(mine[i]),
            ),
          );
        },
      ),
    );
  }

  /// «أتعلم»: مجلدات الأسابيع بدل قائمة طويلة واحدة.
  Widget _weekFolders(List<Lesson> mine, Set<String> done) {
    final byWeek = <int, List<Lesson>>{};
    for (final l in mine) {
      byWeek.putIfAbsent(weekOf(l), () => []).add(l);
    }
    final weeks = byWeek.keys.toList()..sort();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: weeks.length,
      itemBuilder: (_, i) {
        final w = weeks[i];
        final ls = byWeek[w]!;
        final all = ls.every((l) => done.contains(l.id));
        final name = w == 0 ? 'ألعاب' : 'الأسبوع $w';
        return WorldTile(
          emoji: w == 0 ? '🎲' : '📚',
          title: name,
          color: _palette[i % _palette.length],
          emojiSize: 60,
          badge: all,
          onTap: () async {
            await ref.read(voiceServiceProvider).sayAndWait(name);
            if (!mounted) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => KidSectionScreen(
                category: widget.category,
                title: name,
                child: widget.child,
                week: w,
              ),
            ));
          },
        );
      },
    );
  }
}
