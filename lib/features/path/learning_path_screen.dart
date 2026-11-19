import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/curriculum.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../lessons/kid_section_screen.dart' show spokenTitle;
import '../today/today_screen.dart' show curriculumProvider;

const _palette = <Color>[
  Color(0xFF2A9D8F),
  Color(0xFFE76F8B),
  Color(0xFF6C7BD9),
  Color(0xFFE08E45),
  Color(0xFF4FAF8E),
  Color(0xFF58A6D8),
];

/// عبارات قصيرة تُنطق (تعليمية فقط، لا آيات ولا أحاديث).
const kPathLockedSay = 'أكملي المغامرة السابقة أولًا';
const kPathGiftLockedSay = 'هديتك تنتظرك بعد آخر مغامرة';

/// «مسار التعلّم»: شريط عمودي ينزل لتحت. الطفلة لا تختار شيئًا؛
/// تُكمل المغامرة الحالية فتنفتح التي بعدها. ينتهي كل يوم بهدية 🎁.
class LearningPathScreen extends ConsumerStatefulWidget {
  const LearningPathScreen({super.key});

  @override
  ConsumerState<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends ConsumerState<LearningPathScreen> {
  final _currentKey = GlobalKey();
  String? _spokenKey;
  String? _scrolledTo;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
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
        title: const Text('رحلتي 🌟'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/home'),
            icon: const Text('🎮', style: TextStyle(fontSize: 22)),
            label: const Text('العب بحرية'),
          ),
        ],
      ),
      body: SafeArea(
        child: child.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('حدث خطأ')),
          data: (c) => c == null
              ? Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('اختاري من سيتعلم'),
                  ),
                )
              : _body(c),
        ),
      ),
    );
  }

  Widget _body(Child c) {
    final curriculum = ref.watch(curriculumProvider);
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(c.id));
    if (curriculum.isLoading || lessons.isLoading || done.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (curriculum.hasError || lessons.hasError || done.hasError) {
      return const Center(child: Text('تعذر تحميل الرحلة'));
    }
    final path = curriculum.requireValue.pathFor(
      childAge: c.age,
      allLessons: lessons.requireValue,
      completed: done.requireValue,
    );
    final little = c.ageGroup == AgeGroup.early;
    final currentId = path.current?.id ?? 'all';

    // ترحيب صوتي، وتهنئة حين تنتقل الطفلة لمغامرة جديدة.
    if (_spokenKey != currentId) {
      final first = _spokenKey == null;
      _spokenKey = currentId;
      final text = path.finishedAll
          ? 'أحسنتِ يا ${c.name}! أكملتِ كل المغامرات'
          : (first ? 'أهلًا يا ${c.name}! هيا نكمل مغامرتنا' : 'أحسنتِ يا ${c.name}! هيا نكمل');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(voiceServiceProvider).speak(text);
      });
    }
    // ننزل تلقائيًا إلى العقدة الحالية.
    if (_scrolledTo != currentId) {
      _scrolledTo = currentId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _currentKey.currentContext;
        if (mounted && ctx != null) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.4, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
        }
      });
    }

    if (path.week == null) {
      return const Center(child: Text('مغامرات جديدة قادمة قريبًا إن شاء الله'));
    }

    final items = <Widget>[
      _WeekHeader(week: path.week!, little: little, finishedAll: path.finishedAll, name: c.name),
    ];
    var i = 0; // رقم العقدة لتوزيع اللون والانحناء
    for (final d in path.days) {
      items.add(_DayBanner(day: d, little: little));
      for (final n in d.nodes) {
        items.add(_Connector(color: _palette[i % _palette.length]));
        items.add(_NodeRow(
          key: n.state == PathState.current ? _currentKey : null,
          node: n,
          slot: i,
          little: little,
          onTap: () => _onNode(n),
        ));
        i++;
      }
      items.add(const _Connector(color: Color(0xFFFFB84D)));
      items.add(_GiftNode(open: d.complete, little: little, onTap: () => _onGift(d, c.name)));
      items.add(const SizedBox(height: 18));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: items);
  }

  Future<void> _onNode(PathNode n) async {
    if (_busy) return;
    final voice = ref.read(voiceServiceProvider);
    if (n.state == PathState.locked) {
      unawaited(voice.speak(kPathLockedSay));
      return;
    }
    _busy = true;
    try {
      unawaited(voice.speak(spokenTitle(n.lesson.title)));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) await context.push('/lesson/${n.lesson.id}');
    } finally {
      _busy = false;
    }
  }

  void _onGift(PathDay d, String name) {
    final voice = ref.read(voiceServiceProvider);
    unawaited(voice.speak(d.complete ? 'أحسنتِ يا $name! أكملتِ اليوم' : kPathGiftLockedSay));
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.week, required this.little, required this.finishedAll, required this.name});

  final CurriculumWeek week;
  final bool little;
  final bool finishedAll;
  final String name;

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
          child: Mascot(size: little ? 90 : 72, mood: finishedAll ? MascotMood.cheer : MascotMood.happy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Text(
              little ? 'الأسبوع ${week.week} 🌈' : 'الأسبوع ${week.week}: ${week.title}',
              style: AppText.display(little ? 26 : 21),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayBanner extends StatelessWidget {
  const _DayBanner({required this.day, required this.little});

  final PathDay day;
  final bool little;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 2)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: day.complete ? AppColors.leaf : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Text(
              little ? '${day.complete ? '✅' : '🌙'} ${day.day}' : 'اليوم ${day.day} — ${day.title}',
              style: TextStyle(
                fontSize: little ? 22 : 16,
                fontWeight: FontWeight.w800,
                color: day.complete ? Colors.white : AppColors.ink,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 2)),
        ],
      ),
    );
  }
}

/// خط منقّط بين عقدتين.
class _Connector extends StatelessWidget {
  const _Connector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var k = 0; k < 3; k++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.45)),
          ),
      ],
    );
  }
}

String _emojiFor(Lesson l) {
  switch (l.category) {
    case 'quran':
    case 'prophets':
      return '📖';
    case 'akhlaq':
      return '❤️';
    case 'adhkar':
    case 'prayer':
      return '🕌';
    default:
      return l.emoji;
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    super.key,
    required this.node,
    required this.slot,
    required this.little,
    required this.onTap,
  });

  final PathNode node;
  final int slot;
  final bool little;
  final VoidCallback onTap;

  static const _curve = <double>[0, -0.45, 0, 0.45];

  @override
  Widget build(BuildContext context) {
    final state = node.state;
    final base = _palette[slot % _palette.length];
    final color = switch (state) {
      PathState.done => AppColors.leaf,
      PathState.current => base,
      PathState.locked => const Color(0xFFB7C0C9),
    };
    final size = (little ? 116.0 : 96.0) + (state == PathState.current ? 14 : 0);

    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Opacity(
        opacity: state == PathState.locked ? 0.45 : 1,
        child: Text(_emojiFor(node.lesson), style: TextStyle(fontSize: size * 0.46)),
      ),
    );
    if (state == PathState.current) circle = _Pulse(child: circle);

    final badge = switch (state) {
      PathState.done => '⭐',
      PathState.locked => '🔒',
      PathState.current => '',
    };

    return Align(
      alignment: Alignment(_curve[slot % _curve.length], 0),
      child: Semantics(
        button: true,
        label: state == PathState.locked ? 'مغلقة' : node.lesson.title,
        child: PopTap(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  circle,
                  if (badge.isNotEmpty)
                    PositionedDirectional(
                      end: -4,
                      top: -4,
                      child: Text(badge, style: const TextStyle(fontSize: 30)),
                    ),
                  if (state == PathState.current)
                    const PositionedDirectional(
                      start: -64,
                      bottom: 0,
                      child: Mascot(size: 56),
                    ),
                ],
              ),
              if (state != PathState.locked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 170,
                    child: Text(
                      node.lesson.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(little ? 20 : 17),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftNode extends StatelessWidget {
  const _GiftNode({required this.open, required this.little, required this.onTap});

  final bool open;
  final bool little;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = little ? 96.0 : 80.0;
    return Center(
      child: PopTap(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? const Color(0xFFFFE9A8) : const Color(0xFFE3E8ED),
            border: Border.all(color: open ? AppColors.sun : const Color(0xFFB7C0C9), width: 4),
          ),
          child: Opacity(
            opacity: open ? 1 : 0.5,
            child: Text(open ? '🎁' : '🔒', style: TextStyle(fontSize: size * 0.5)),
          ),
        ),
      ),
    );
  }
}

/// نبض لطيف على العقدة الحالية.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.06 * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}
