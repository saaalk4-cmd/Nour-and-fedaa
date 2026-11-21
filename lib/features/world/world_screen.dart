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
import '../home/who_learns_screen.dart' show characterFor, colorFor;
import '../lessons/kid_section_screen.dart' show spokenTitle;
import '../song/song_screen.dart' show currentDayKey, dayJustCompleted;
import '../today/today_screen.dart' show curriculumProvider;

/// عبارات قصيرة تُنطق (تعليمية فقط، لا آيات ولا أحاديث).
const kWorldMissionLockedGiftSay = 'هديتك تنتظرك بعد مهمات اليوم';
const kWorldDoneSay = 'أنتِ مستكشفة صغيرة';

/// أقسام «الدين والأذكار» (شاشة قديمة باقية للروابط).
const deenSectionIds = <String>[
  SectionIds.quran,
  SectionIds.prayer,
  SectionIds.adhkar,
  SectionIds.prophets,
  SectionIds.seerah,
  SectionIds.figures,
];

/// «عالمنا»: الشاشة الرئيسية بعد اختيار الطفلة.
/// من فوق لتحت: مغامرة اليوم (مضغوطة) ← الألعاب ← شبكة الأقسام. كل شيء بمكان واحد واضح.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  String? _spokenKey;
  bool _busy = false;

  /// يوم المغامرة الحالية عند آخر بناء (لمعرفة اللحظة التي تكتمل فيها مغامرة اليوم).
  String? _dayKey;

  void _say(String text) => unawaited(ref.read(voiceServiceProvider).speak(text));

  Future<void> _go(String say, String route) async {
    if (_busy) return;
    _busy = true;
    try {
      // ننتظر حتى تكتمل الجملة ثم نفتح (وإلا تنقطع).
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
    return child.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('حدث خطأ'))),
      data: (c) => c == null
          ? Scaffold(body: Center(child: SunButton(label: 'من سيتعلم؟', onTap: () => context.go('/'))))
          : _body(c),
    );
  }

  Widget _body(Child c) {
    final curriculum = ref.watch(curriculumProvider);
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(c.id));
    final states = ref.watch(sectionStatesProvider).valueOrNull ?? const <String, bool>{};
    final stars = ref.watch(gamificationProfileProvider(c.id)).valueOrNull?.stars;
    final songButton = ref.watch(songButtonProvider).valueOrNull ?? true;
    final songAfter = ref.watch(songAfterAdventureProvider).valueOrNull ?? true;

    PathWeek? path;
    if (curriculum.hasValue && lessons.hasValue && done.hasValue) {
      path = curriculum.requireValue.pathFor(
        childAge: c.age,
        allLessons: lessons.requireValue,
        completed: done.requireValue,
      );
      final key = path.current?.id ?? 'all';
      final day = currentDayKey(path);
      final justDone = dayJustCompleted(_dayKey, day);
      _dayKey = day;
      if (justDone && songAfter) {
        // 🎉 أنهت مغامرة اليوم للتو: الأغنية احتفالًا (بدل الجملة، فلا يتداخل صوتان).
        _spokenKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(context.push('/song?celebrate=1'));
        });
      } else if (_spokenKey != key) {
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
    final sections = [for (final s in appSections) if (on(s.id)) s];

    return KidScaffold(
      background: bg,
      leading: _KidButton(
        child: c,
        onTap: () {
          ref.read(selectedChildIdProvider.notifier).state = null;
          context.go('/');
        },
      ),
      title: 'أهلًا يا ${c.name}',
      actions: [
        if (stars != null) ...[_StarChip(stars: stars), const SizedBox(width: 6)],
        GlossyButton(
          color: const Color(0xFFA463E8),
          label: 'خريطة الأسبوع',
          icon: Icons.map_rounded,
          size: 56,
          onTap: () => _go('خريطة الأسبوع', '/path'),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(children: [
              if (path == null && (curriculum.hasError || lessons.hasError || done.hasError))
                const ParchmentCard(child: Text('تعذر تحميل المهمة، جربي مرة ثانية', textAlign: TextAlign.center))
              else if (path == null)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else
                MissionCard(
                  path: path,
                  child: c,
                  onStart: (l) => _openLesson(l.id),
                  onGift: (d) => _say(d.complete ? 'أحسنتِ يا ${c.name}! أكملتِ اليوم' : kWorldMissionLockedGiftSay),
                  onDone: () => _say('أحسنتِ يا ${c.name}! $kWorldDoneSay'),
                ),
              const SizedBox(height: 16),
              // صف دوائر بالصور بدل اللافتات المكدسة: الألعاب، ورد اليوم، أغنيتنا.
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (ref.watch(gamesEnabledProvider).valueOrNull ?? true)
                    HomeBubble(
                      label: 'الألعاب',
                      color: const Color(0xFF3D8BEA),
                      art: const [Art.lamaaCheer],
                      onTap: () => _go('الألعاب', '/games'),
                    ),
                  if (c.age >= 5)
                    HomeBubble(
                      label: 'ورد اليوم',
                      color: const Color(0xFF2A9D8F),
                      art: const [Art.secQuran],
                      onTap: () => _go('ورد اليوم', '/section/quran'),
                    ),
                  if (songButton)
                    HomeBubble(
                      label: 'أغنيتنا',
                      color: const Color(0xFFFF8FB1),
                      art: const [Art.fedaaCheer, Art.nourCheer],
                      onTap: () => context.push('/song'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Align(alignment: AlignmentDirectional.centerStart, child: OutlineText('عالمي', size: 28, maxLines: 1)),
              const SizedBox(height: 8),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.02,
              children: [
                for (final s in sections)
                  WorldTile(
                    emoji: s.emoji,
                    art: s.art,
                    title: s.title,
                    color: SectionLook.of(s.id).color,
                    onTap: () => _go(spokenTitle(s.title), '/section/${s.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// كارت «مغامرة اليوم»: مضغوط وواضح — درس اليوم بالترتيب، نجوم اليوم، «ابدأ الآن»، وهدايا الأسبوع.
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF8F6BFF), Color(0xFFC98BFF), Color(0xFFFF9EC7)],
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x557A4FD6), blurRadius: 14, offset: Offset(0, 7))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ArtImage(current == null ? Art.medal : Art.lamaaPoint, width: 74, height: 74),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlineText(current == null ? 'أحسنتِ!' : 'مغامرة اليوم', size: 20, stroke: const Color(0xFF5B3BB5), maxLines: 1),
                    const SizedBox(height: 2),
                    Text(
                      current == null ? kWorldDoneSay : '${current.emoji} ${current.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(23, color: Colors.white).copyWith(
                        shadows: const [Shadow(color: Color(0xFF5B3BB5), blurRadius: 3, offset: Offset(0, 1.5))],
                      ),
                    ),
                    if (totalToday > 0) ...[
                      const SizedBox(height: 4),
                      StarRow(filled: doneToday, total: totalToday, size: 22),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SunButton(
              label: current == null ? 'أحسنتِ!' : 'ابدأ الآن',
              height: 58,
              onTap: current == null ? onDone : () => onStart(current),
            ),
          ),
          if (path.days.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
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
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: open ? 1 : 0.5, child: const ArtImage(Art.icGift, width: 48)),
              if (!open) const ArtImage(Art.icLock, width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر صورة الطفلة (يرجع لاختيار الطفلة).
class _KidButton extends StatelessWidget {
  const _KidButton({required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'تغيير الطفلة',
      child: PopTap(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: colorFor(child), width: 4),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: ArtImage(characterFor(child), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// نجوم الطفلة (من الدروس والألعاب).
class _StarChip extends StatelessWidget {
  const _StarChip({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFF2A93B), width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ArtImage(Art.starOn, width: 26, height: 26),
          const SizedBox(width: 4),
          Text('$stars', style: AppText.display(22, color: Wood.text)),
        ],
      ),
    );
  }
}

/// دائرة كبيرة بالصورة وكلمة واحدة تحتها (للبنت اللي لسه مش بتقرأ: الصورة تكفي).
class HomeBubble extends StatelessWidget {
  const HomeBubble({super.key, required this.label, required this.color, required this.art, required this.onTap});

  final String label;
  final Color color;

  /// صورة أو صورتان جنب بعض.
  final List<String> art;
  final VoidCallback onTap;

  static const double size = 104;

  @override
  Widget build(BuildContext context) {
    final each = art.length == 1 ? size * 0.74 : size * 0.42;
    return Semantics(
      button: true,
      label: label,
      child: PopTap(
        onTap: onTap,
        child: SizedBox(
          width: size + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, 0.55)!, color]),
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final a in art) ArtImage(a, width: each, height: each * 1.15)],
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: OutlineText(label, size: 20, stroke: Color.lerp(color, Colors.black, 0.35)!, maxLines: 1)),
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
    return KidScaffold(
      title: 'الدين والأذكار',
      background: Art.bgHouse,
      onBack: () => context.canPop() ? context.pop() : context.go('/world'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final s in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WoodSign(
                icon: ArtImage(s.art, width: 52, height: 52),
                title: s.title,
                onTap: () async {
                  await ref.read(voiceServiceProvider).sayAndWait(spokenTitle(s.title));
                  if (context.mounted) await context.push('/section/${s.id}');
                },
              ),
            ),
        ],
      ),
    );
  }
}
