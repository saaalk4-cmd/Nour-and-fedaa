import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../data/content/curriculum.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../home/who_learns_screen.dart' show characterFor;
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
const kPathGateSay = 'مغامرة جديدة تنتظرك';

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
    return child.when(
      loading: () => _frame(const Center(child: CircularProgressIndicator())),
      error: (_, __) => _frame(const Center(child: Text('حدث خطأ'))),
      data: (c) => c == null
          ? _frame(Center(child: SunButton(label: 'من سيتعلم؟', onTap: () => context.go('/'))))
          : _body(c),
    );
  }

  /// نفس إطار العالم: خلفية مرسومة، صورة البنت للتبديل، ولافتة «العب بحرية» للرجوع.
  Widget _frame(Widget body, {String bg = Art.bgSky, Child? c}) {
    return KidScaffold(
      background: bg,
      veil: 0.22,
      title: 'رحلتي',
      leading: c == null
          ? null
          : PicButton(
              characterFor(c),
              size: 60,
              label: 'تغيير الطفلة',
              onTap: () {
                ref.read(selectedChildIdProvider.notifier).state = null;
                context.go('/');
              },
            ),
      onBack: c == null ? () => context.go('/') : null,
      actions: [
        ArtButton(art: Art.signpost, label: 'العب بحرية', size: 64, onTap: () => context.canPop() ? context.pop() : context.go('/world')),
      ],
      body: body,
    );
  }

  Widget _body(Child c) {
    final curriculum = ref.watch(curriculumProvider);
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(c.id));
    if (curriculum.isLoading || lessons.isLoading || done.isLoading) {
      return _frame(const Center(child: CircularProgressIndicator()), c: c);
    }
    if (curriculum.hasError || lessons.hasError || done.hasError) {
      return _frame(const Center(child: Text('تعذر تحميل الرحلة')), c: c);
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
      return _frame(const Center(child: Text('مغامرات جديدة قادمة قريبًا إن شاء الله')), c: c);
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
    items.add(const SizedBox(height: 8));
    items.add(path.finishedAll
        ? _EndNode(art: Art.medal, onTap: () => _say('أحسنتِ يا ${c.name}! أنتِ مستكشفة صغيرة'))
        : _EndNode(art: Art.gate, onTap: () => _say(kPathGateSay)));
    final bg = Art.weekBackgrounds[(path.week!.week - 1) % Art.weekBackgrounds.length];
    return _frame(ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: items), bg: bg, c: c);
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
      await voice.stop(); // الدرس يقول اسمه أول ما يفتح
      if (mounted) await context.push('/lesson/${n.lesson.id}');
    } finally {
      _busy = false;
    }
  }

  void _say(String text) => unawaited(ref.read(voiceServiceProvider).speak(text));

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
          child: ArtImage(Art.lamaa, height: little ? 90 : 72),
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
              little ? 'الأسبوع ${week.week}' : 'الأسبوع ${week.week}: ${week.title}',
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
      PathState.done => Art.star,
      PathState.locked => Art.lock,
      PathState.current => '',
    };

    final cx = _curve[slot % _curve.length];
    final nodeWidget = Align(
      alignment: Alignment(cx, 0),
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
                      child: ArtImage(badge, width: 42),
                    ),
                  if (state == PathState.current)
                    Positioned(
                      left: cx > 0 ? -84 : null,
                      right: cx > 0 ? null : -84,
                      bottom: 0,
                      // لَمعة تشير إلى العقدة من الجهة المقابلة.
                      child: Transform.flip(
                        flipX: cx <= 0,
                        child: const ArtImage(Art.lamaaPoint, width: 78),
                      ),
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

    // زينة على الجهة المقابلة للعقدة (غير العقدة الحالية: مكان لَمعة).
    final decorName = Art.decor[slot % Art.decor.length];
    final decorLeft = cx > 0 || (cx == 0 && slot.isEven);
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (state != PathState.current)
            Positioned(
              left: decorLeft ? 6 : null,
              right: decorLeft ? null : 6,
              bottom: 0,
              child: IgnorePointer(child: ArtImage(decorName, height: little ? 92 : 80)),
            ),
          nodeWidget,
        ],
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
    final size = little ? 104.0 : 88.0;
    return Center(
      child: Semantics(
        button: true,
        label: 'هدية اليوم',
        child: PopTap(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: open ? 1 : 0.5, child: ArtImage(Art.gift, width: size)),
                if (!open) ArtImage(Art.lock, width: size * 0.42),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// نهاية المسار: بوابة المغامرة القادمة، أو ميدالية «مستكشفة صغيرة» عند إنهاء كل شيء.
class _EndNode extends StatelessWidget {
  const _EndNode({required this.art, required this.onTap});

  final String art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PopTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ArtImage(art, width: 210),
        ),
      ),
    );
  }
}

/// خلفية المسار: صورة الأسبوع + طبقة بيضاء خفيفة ليبقى المسار واضحًا.
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
