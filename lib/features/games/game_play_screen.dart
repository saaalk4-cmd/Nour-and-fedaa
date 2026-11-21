import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/cheers.dart';
import '../../core/audio/sound_service.dart';
import '../../core/design/art.dart';
import '../../core/design/joy.dart';
import '../../core/design/kit.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../home/who_learns_screen.dart' show colorFor;
import 'engines/choose_engine.dart';
import 'engines/count_find_engine.dart';
import 'engines/memory_engine.dart';
import 'engines/order_engine.dart';
import 'engines/sort_engine.dart';
import 'game_content.dart';
import 'game_kit.dart';
import 'game_providers.dart';
import 'game_repository.dart';

/// يبني جولة اللعبة حسب نوعها ونسخة العمر. كل المحتوى من البيانات (لا شيء ثابت في الكود).
class RoundFactory {
  RoundFactory(this.game, this.track, this.level, this.kit) {
    if (game.type == GameTypes.choose) _targets = planTargets(levelPool(game, level), level.rounds, kit);
    if (game.type == GameTypes.scenario) {
      final pool = kit.shuffled(game.scenarios);
      _scenarios = [for (var i = 0; i < level.rounds; i++) pool[i % pool.length]];
    }
  }

  final GameDef game;
  final GameTrack track;
  final GameLevel level;
  final GameKit kit;
  List<GameItem> _targets = const [];
  List<GameScenario> _scenarios = const [];

  bool get _drag => (level.params['mode'] as String? ?? track.mode) == 'drag';

  Widget build(int round, RoundDone done) {
    final key = ValueKey('${game.id}-${level.key}-$round');
    final pool = levelPool(game, level);
    switch (game.type) {
      case GameTypes.choose:
        return ChooseRound(key: key, game: game, track: track, level: level, target: _targets[round], kit: kit, onDone: done);
      case GameTypes.scenario:
        return ScenarioRound(key: key, scenario: _scenarios[round], kit: kit, onDone: done, maxOptions: level.intParam('options', kit.little ? 2 : 3));
      case GameTypes.order:
        final count = level.intParam('count', pool.length).clamp(2, pool.length);
        return OrderRound(
          key: key,
          steps: pool.take(count).toList(),
          kit: kit,
          onDone: done,
          drag: _drag,
          prompt: level.strParam('prompt', track.prompt ?? 'رتّبي الخطوات'),
        );
      case GameTypes.memory:
        final pairs = level.intParam('pairs', kit.little ? 2 : 4).clamp(2, pool.length);
        return MemoryRound(key: key, items: kit.shuffled(pool).take(pairs).toList(), kit: kit, onDone: done, words: track.mode == 'words');
      case GameTypes.sort:
        final ids = level.listParam('groups');
        final groups = [for (final g in game.groups) if (ids.isEmpty || ids.contains(g.id)) g];
        final items = kit.shuffled(pool.where((i) => groups.any((g) => g.id == i.group))).take(level.intParam('perRound', kit.little ? 4 : 6)).toList();
        return SortRound(key: key, items: items, groups: groups, kit: kit, onDone: done, drag: _drag, prompt: level.strParam('prompt', track.prompt ?? 'ضعي كل شيء في سلّته'));
      case GameTypes.count:
        final lo = level.intParam('min', 1), hi = level.intParam('max', kit.little ? 3 : 6);
        final n = lo + kit.rng.nextInt(hi - lo + 1);
        final thing = pool[kit.rng.nextInt(pool.length)];
        return CountRound(key: key, thing: thing, n: n, kit: kit, onDone: done, tapMode: track.mode == 'tap', extra: level.intParam('extra', 2));
      case GameTypes.find:
        final target = pool[kit.rng.nextInt(pool.length)];
        final distractors = level.listParam('distractors').isNotEmpty
            ? level.listParam('distractors')
            : [for (final i in game.items) if (i.id != target.id) i.emoji];
        return FindRound(
          key: key,
          target: target,
          distractors: distractors,
          kit: kit,
          onDone: done,
          cells: level.intParam('cells', kit.little ? 6 : 16),
          targets: level.intParam('targets', 1),
        );
    }
    return const SizedBox.shrink();
  }
}

/// جلسة لعب: جولات المستوى، نجمة لكل جولة (من أول أو ثاني محاولة)، ثم النتيجة والحفظ.
class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key, required this.gameId, required this.levelKey});

  final String gameId;
  final String levelKey;

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  GameKit? _kit;
  RoundFactory? _factory;
  int _round = 0;
  int _stars = 0;
  bool _muted = false;
  GameSaveResult? _result;
  late final int _seed = DateTime.now().millisecondsSinceEpoch;

  void _setup(GameDef g, GameTrack track, GameLevel lv, Child c) {
    if (_kit != null) return;
    final kit = GameKit(
      voice: ref.read(voiceServiceProvider),
      ayah: ref.read(ayahPlayerProvider),
      sound: ref.read(soundServiceProvider),
      childName: c.name,
      little: c.age <= 4,
      respectful: g.respectful,
      seed: _seed,
    );
    _kit = kit;
    _factory = RoundFactory(g, track, lv, kit);
  }

  @override
  void dispose() {
    unawaited(_kit?.stop());
    super.dispose();
  }

  int _streak = 0;
  JoyLevel? _joy;
  int _joyN = 0;

  void _showJoy(JoyLevel level, GameDef g) {
    if (!g.respectful) ref.read(soundServiceProvider).play(SoundEffect.joy);
    setState(() {
      _joy = level;
      _joyN++;
    });
    final n = _joyN;
    Future<void>.delayed(JoyBurst.duration, () {
      if (mounted && _joyN == n) setState(() => _joy = null);
    });
  }

  Future<void> _roundDone(int slips, GameDef g, GameLevel lv, Child c) async {
    if (slips <= 1) _stars++;
    _streak = slips == 0 ? _streak + 1 : 0;
    if (slips == 0 && _streak % 3 == 0 && _round + 1 < lv.rounds) {
      // ثلاث جولات ورا بعض من أول مرة: احتفال أكبر وعبارة «ما شاء الله» (هادئ في ألعاب القرآن).
      _showJoy(JoyLevel.medium, g);
      await _kit?.sayWait(Cheers.forStreak(c.name));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (_round + 1 < lv.rounds) {
      setState(() => _round++);
      return;
    }
    final res = await ref.read(gameRepositoryProvider).saveRound(childId: c.id, gameId: g.id, levelKey: lv.key, stars: _stars);
    ref.invalidate(gameProgressProvider(c.id));
    ref.invalidate(gamificationProfileProvider(c.id));
    if (mounted) {
      setState(() => _result = res);
      _showJoy(JoyLevel.big, g);
    }
  }

  Future<void> _toggleMute() async {
    final kit = _kit;
    setState(() => _muted = !_muted);
    if (kit == null) return;
    if (_muted) await kit.stop();
    // كتم كل الأصوات (الكلام والمؤثرات والتلاوة) حتى تُشغَّل مرة ثانية.
    await ref.read(voiceServiceProvider).setEnabled(!_muted);
    await ref.read(soundServiceProvider).setEnabled(!_muted);
    ref.invalidate(voiceEnabledProvider);
    ref.invalidate(soundEnabledProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(selectedChildProvider).valueOrNull;
    final g = ref.watch(gameCatalogProvider).valueOrNull?.byId(widget.gameId);
    if (c == null || g == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final track = g.trackFor(c.age);
    final li = track.levels.indexWhere((l) => l.key == widget.levelKey);
    if (li < 0) return const Scaffold(body: Center(child: Text('المستوى غير موجود')));
    final lv = track.levels[li];
    _setup(g, track, lv, c);
    final result = _result;
    return KidScaffold(
      title: lv.title,
      background: Art.bgSky,
      veil: 0.15,
      onBack: () => context.pop(),
      actions: [
        GlossyButton(
          color: const Color(0xFF3D8BEA),
          label: _muted ? 'تشغيل الصوت' : 'كتم الصوت',
          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onTap: _toggleMute,
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(
            child: result != null
                ? _ResultView(game: g, track: track, levelIndex: li, stars: _stars, result: result, child: c)
                : Column(
                    children: [
                      _Dots(total: lv.rounds, done: _round),
                      const SizedBox(height: 6),
                      Expanded(child: _factory!.build(_round, (s) => _roundDone(s, g, lv, c))),
                    ],
                  ),
          ),
          if (_joy != null)
            Positioned.fill(
              child: JoyBurst(
                key: ValueKey(_joyN),
                level: _joy!,
                text: g.respectful ? null : 'ما شاء الله!',
                calm: g.respectful,
                reduceMotion: ref.watch(reduceMotionProvider).valueOrNull ?? false,
              ),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == done ? 20 : 14,
            height: i == done ? 20 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? const Color(0xFFFFC21F) : Colors.white,
              border: Border.all(color: Wood.dark, width: 2),
            ),
          ),
      ],
    );
  }
}

/// النتيجة: البنت تحتفل، النجوم، وما انفتح (مستوى جديد أو ميدالية اللعبة).
class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.game, required this.track, required this.levelIndex, required this.stars, required this.result, required this.child});

  final GameDef game;
  final GameTrack track;
  final int levelIndex;
  final int stars;
  final GameSaveResult result;
  final Child child;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  GameLevel get lv => widget.track.levels[widget.levelIndex];
  bool get _passed => widget.stars >= lv.passStars;
  bool get _hasNext => widget.levelIndex + 1 < widget.track.levels.length;
  bool get _opened => _hasNext && _passed && widget.result.previousBest < lv.passStars;
  bool get _champion => !_hasNext && _passed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = widget.child.name;
      final extra = _opened
          ? ' فتحتِ ${widget.track.levels[widget.levelIndex + 1].title}'
          : (_champion ? ' أنتِ بطلة ${widget.game.title}' : '');
      ref.read(voiceServiceProvider).sayAndWait('أحسنتِ يا $name!$extra');
    });
  }

  @override
  Widget build(BuildContext context) {
    final little = widget.child.age <= 4;
    final next = _hasNext ? widget.track.levels[widget.levelIndex + 1] : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Center(
          child: ArtImage(little ? Art.nourCheer : Art.fedaaCheer, height: 200),
        ),
        ParchmentCard(
          child: Column(
            children: [
              Text('أحسنتِ يا ${widget.child.name}!', style: AppText.display(32, color: Wood.text)),
              const SizedBox(height: 6),
              StarRow(filled: widget.stars, total: lv.rounds, size: 40),
              const SizedBox(height: 6),
              Text(
                _passed ? 'أكملتِ ${lv.title}' : 'لعبتِ جيدًا! العبي مرة ثانية لتجمعي نجومًا أكثر',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        if (_opened && next != null) ...[
          const SizedBox(height: 14),
          Center(child: _Prize(art: Art.icGift, text: 'فتحتِ: ${next.title}', color: colorFor(widget.child))),
        ],
        if (_champion) ...[
          const SizedBox(height: 14),
          Center(child: _Prize(art: Art.medal, text: 'بطلة ${widget.game.title}', color: colorFor(widget.child))),
        ],
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            SunButton(
              label: 'العبي مرة ثانية',
              height: 58,
              onTap: () => context.pushReplacement('/games/${widget.game.id}/play/${lv.key}'),
            ),
            if (next != null && (_passed || widget.result.previousBest >= lv.passStars))
              SunButton(
                label: next.title,
                height: 58,
                onTap: () => context.pushReplacement('/games/${widget.game.id}/play/${next.key}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Prize extends StatefulWidget {
  const _Prize({required this.art, required this.text, required this.color});

  final String art;
  final String text;
  final Color color;

  @override
  State<_Prize> createState() => _PrizeState();
}

class _PrizeState extends State<_Prize> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: Column(
        children: [
          ArtImage(widget.art, width: 120, height: 120),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: widget.color, width: 3)),
            child: Text(widget.text, style: AppText.display(22, color: Wood.text)),
          ),
        ],
      ),
    );
  }
}
