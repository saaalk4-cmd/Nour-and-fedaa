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
import '../../data/repositories/settings_repository.dart';
import '../home/sections.dart';
import '../home/who_learns_screen.dart' show characterFor;
import '../lessons/kid_section_screen.dart' show spokenTitle;
import '../today/today_screen.dart' show curriculumProvider;

/// عبارات قصيرة تُنطق (تعليمية فقط، لا آيات ولا أحاديث).
const kWorldMissionLockedGiftSay = 'هديتك تنتظرك بعد مهمات اليوم';
const kWorldDoneSay = 'أنتِ مستكشفة صغيرة';

/// أقسام «الدين والأذكار» تحت لافتة واحدة.
const deenSectionIds = <String>[
  SectionIds.quran,
  SectionIds.prayer,
  SectionIds.adhkar,
  SectionIds.prophets,
  SectionIds.seerah,
  SectionIds.figures,
];

/// «عالمنا»: الشاشة الرئيسية بعد اختيار الطفلة.
/// كارت «مهمة جديدة» يفتح درس اليوم بالترتيب، وتحته لافتات خشب للعب الحر.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  String? _spokenKey;
  bool _busy = false;

  void _say(String text) => unawaited(ref.read(voiceServiceProvider).speak(text));

  Future<void> _go(String say, String route) async {
    if (_busy) return;
    _busy = true;
    try {
      // ننتظر حتى تكتمل الجملة ثم نفتح (وإلا تنقطع عند فتح الدرس).
      await ref.read(voiceServiceProvider).sayAndWait(say);
      if (mounted) await context.push(route);
    } finally {
      _busy = false;
    }
  }

  /// الدرس يقول اسمه بنفسه أول ما يفتح (نفس الشيء في كل التطبيق).
  Future<void> _openLesson(String id) async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(voiceServiceProvider).stop();
      if (mounted) await context.push('/lesson/$id');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
    return Scaffold(
      body: child.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('حدث خطأ')),
        data: (c) {
          if (c == null) {
            return Center(
              child: SunButton(label: 'من سيتعلم؟', onTap: () => context.go('/')),
            );
          }
          return _body(c);
        },
      ),
    );
  }

  Widget _body(Child c) {
    final curriculum = ref.watch(curriculumProvider);
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(c.id));
    final states = ref.watch(sectionStatesProvider).valueOrNull ?? const <String, bool>{};
    final little = c.ageGroup == AgeGroup.early;

    PathWeek? path;
    if (curriculum.hasValue && lessons.hasValue && done.hasValue) {
      path = curriculum.requireValue.pathFor(
        childAge: c.age,
        allLessons: lessons.requireValue,
        completed: done.requireValue,
      );
      final key = path.current?.id ?? 'all';
      if (_spokenKey != key) {
        final first = _spokenKey == null;
        _spokenKey = key;
        final text = path.finishedAll
            ? 'أحسنتِ يا ${c.name}! $kWorldDoneSay'
            : (first ? 'أهلًا يا ${c.name}! هيا نبدأ مهمتنا' : 'أحسنتِ يا ${c.name}! هيا نكمل');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _say(text);
        });
      }
    }

    bool on(String id) => states[id] ?? true;
    final bg = path?.week == null
        ? Art.bgSky
        : Art.weekBackgrounds[(path!.week!.week - 1) % Art.weekBackgrounds.length];

    final signs = <Widget>[
      if (on(SectionIds.learn))
        WoodSign(
          icon: const Text('📚'),
          title: 'أتعلم',
          subtitle: little ? null : 'حروف وأرقام واكتشاف',
          onTap: () => _go('أتعلم', '/section/${SectionIds.learn}'),
        ),
      if (deenSectionIds.any(on))
        WoodSign(
          icon: const Text('🕌'),
          title: 'الدين والأذكار',
          subtitle: little ? null : 'قرآن وصلاة وأنبياء',
          onTap: () => _go('الدين والأذكار', '/world/deen'),
        ),
      if (on(SectionIds.akhlaq))
        WoodSign(
          icon: const Text('❤️'),
          title: 'القيم والأخلاق',
          onTap: () => _go('القيم والأخلاق', '/section/${SectionIds.akhlaq}'),
        ),
      if (on(SectionIds.achievements))
        WoodSign(
          icon: const ArtImage(Art.medal),
          title: 'إنجازاتي',
          onTap: () => _go('إنجازاتي', '/section/${SectionIds.achievements}'),
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ArtImage(bg, fit: BoxFit.cover)),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TopBar(
                onHome: () {
                  ref.read(selectedChildIdProvider.notifier).state = null;
                  context.go('/');
                },
                onMap: () => _go('خريطة الأسبوع', '/path'),
              ),
              const SizedBox(height: 10),
              _Greeting(child: c, little: little),
              const SizedBox(height: 14),
              if (path == null && (curriculum.hasError || lessons.hasError || done.hasError))
                const ParchmentCard(child: Text('تعذر تحميل المهمة، جربي مرة ثانية', textAlign: TextAlign.center))
              else if (path == null)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
              else
                MissionCard(
                  path: path,
                  child: c,
                  onStart: (l) => _openLesson(l.id),
                  onGift: (d) => _say(d.complete ? 'أحسنتِ يا ${c.name}! أكملتِ اليوم' : kWorldMissionLockedGiftSay),
                  onDone: () => _say('أحسنتِ يا ${c.name}! $kWorldDoneSay'),
                ),
              const SizedBox(height: 18),
              for (final s in signs) Padding(padding: const EdgeInsets.only(bottom: 12), child: s),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHome, required this.onMap});

  final VoidCallback onHome;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlossyButton(color: const Color(0xFF4CB944), label: 'تغيير الطفلة', icon: Icons.home_rounded, onTap: onHome),
        const Spacer(),
        GlossyButton(color: const Color(0xFFA463E8), label: 'خريطة الأسبوع', icon: Icons.map_rounded, onTap: onMap),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.child, required this.little});

  final Child child;
  final bool little;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(width: 110, height: 130, child: ArtImage(characterFor(child), fit: BoxFit.contain)),
        const SizedBox(width: 8),
        Expanded(
          child: ParchmentCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلًا يا ${child.name}!', style: AppText.display(30, color: Wood.text)),
                if (!little) const Text('مغامرتك اليوم جاهزة', style: TextStyle(fontSize: 17)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// كارت «مهمة جديدة!»: درس اليوم الحالي + نجوم اليوم + زر «ابدأ الآن» + هدايا الأسبوع.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.path,
    required this.child,
    required this.onStart,
    required this.onGift,
    required this.onDone,
  });

  final PathWeek path;
  final Child child;
  final void Function(Lesson lesson) onStart;
  final void Function(PathDay day) onGift;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final current = path.current;
    PathDay? today;
    for (final d in path.days) {
      if (d.nodes.any((n) => n.state == PathState.current)) {
        today = d;
        break;
      }
    }
    final doneToday = today?.nodes.where((n) => n.state == PathState.done).length ?? 0;
    final totalToday = today?.nodes.length ?? 0;

    final Widget inner;
    if (current == null) {
      inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kWorldDoneSay, textAlign: TextAlign.center, style: AppText.display(28, color: Wood.text)),
          const SizedBox(height: 10),
          SunButton(label: 'أحسنتِ!', onTap: onDone),
        ],
      );
    } else {
      inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(current.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(26, color: Wood.text),
                ),
              ),
            ],
          ),
          if (totalToday > 0) ...[
            const SizedBox(height: 8),
            StarRow(filled: doneToday, total: totalToday, size: 34),
          ],
          const SizedBox(height: 12),
          SunButton(label: 'ابدأ الآن', onTap: () => onStart(current)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9F7BFF), Color(0xFFD9A6FF), Color(0xFFFFD1E8)],
        ),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [BoxShadow(color: Color(0x557A4FD6), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          ArtImage(current == null ? Art.medal : Art.lamaaPoint, height: 110),
          RibbonBanner(text: current == null ? 'أحسنتِ!' : 'مهمة جديدة!'),
          const SizedBox(height: 10),
          ParchmentCard(child: inner),
          if (path.days.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [for (final d in path.days) _DayGift(day: d, onTap: () => onGift(d))],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayGift extends StatelessWidget {
  const _DayGift({required this.day, required this.onTap});

  final PathDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = day.complete;
    return Semantics(
      button: true,
      label: 'هدية اليوم ${day.day}',
      child: PopTap(
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: open ? 1 : 0.5, child: const ArtImage(Art.icGift, width: 56)),
              if (!open) const ArtImage(Art.icLock, width: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// «الدين والأذكار»: لافتة لكل قسم ديني.
class DeenScreen extends ConsumerWidget {
  const DeenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states = ref.watch(sectionStatesProvider).valueOrNull ?? const <String, bool>{};
    final visible = [for (final id in deenSectionIds) if (states[id] ?? true) sectionById(id)];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: ArtImage(Art.bgHouse, fit: BoxFit.cover)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    GlossyButton(
                      color: const Color(0xFFFFB300),
                      label: 'رجوع',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => context.canPop() ? context.pop() : context.go('/world'),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: OutlineText('الدين والأذكار', size: 34, maxLines: 1)),
                    const SizedBox(width: 64),
                  ],
                ),
                const SizedBox(height: 16),
                for (final s in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WoodSign(
                      icon: Text(s.emoji),
                      title: s.title,
                      onTap: () async {
                        await ref.read(voiceServiceProvider).sayAndWait(spokenTitle(s.title));
                        if (context.mounted) await context.push('/section/${s.id}');
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
