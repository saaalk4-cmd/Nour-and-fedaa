import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/art.dart';
import '../game_content.dart';
import '../game_kit.dart';

/// يملأ قالب نص مثل «أين {label}؟» من عنصر.
String fillTemplate(String t, GameItem i) => t
    .replaceAll('{label}', i.label)
    .replaceAll('{say}', i.spoken)
    .replaceAll('{letter}', i.letter ?? '')
    .replaceAll('{emoji}', i.emoji);

/// يختار هدف كل جولة: كل عناصر المجموعة تظهر قبل أن تتكرر، بلا تكرار متتالٍ.
List<GameItem> planTargets(List<GameItem> pool, int rounds, GameKit kit) {
  final out = <GameItem>[];
  var bag = <GameItem>[];
  var guard = 0;
  while (out.length < rounds && guard++ < 500) {
    if (bag.isEmpty) bag = kit.shuffled(pool);
    final next = bag.removeAt(0);
    if (out.isNotEmpty && out.last.id == next.id && pool.length > 1) {
      bag.add(next);
      continue;
    }
    out.add(next);
  }
  return out;
}

/// العناصر المسموح بها في المستوى (pool) أو كلها.
List<GameItem> levelPool(GameDef g, GameLevel lv) {
  final ids = lv.listParam('pool');
  if (ids.isEmpty) return g.items;
  return [for (final id in ids) g.item(id)];
}

/// «اسمعي واختاري»: صوت (تلاوة الشيخ أو كلمة) أو صورة، ثم اختيار من بطاقات.
/// نسخة نور: صورتان كبيرتان بلا كتابة. نسخة فداء: كلمات أو حروف واختيارات أكثر.
class ChooseRound extends StatefulWidget {
  const ChooseRound({
    super.key,
    required this.game,
    required this.track,
    required this.level,
    required this.target,
    required this.kit,
    required this.onDone,
  });

  final GameDef game;
  final GameTrack track;
  final GameLevel level;
  final GameItem target;
  final GameKit kit;
  final RoundDone onDone;

  @override
  State<ChooseRound> createState() => _ChooseRoundState();
}

class _ChooseRoundState extends State<ChooseRound> {
  late final List<GameItem> _options;
  final Set<String> _tried = {};
  bool _solved = false;
  int _burst = 0;
  String _mood = Art.lamaaThink;

  GameLevel get lv => widget.level;
  GameKit get kit => widget.kit;
  String get _optField => lv.strParam('show', widget.track.params['show'] as String? ?? (kit.little ? 'emoji' : 'emoji+label'));
  String get _promptShow => lv.strParam('promptShow', widget.track.params['promptShow'] as String? ?? 'none');

  @override
  void initState() {
    super.initState();
    final pool = levelPool(widget.game, lv);
    final n = lv.intParam('options', kit.little ? 2 : 3).clamp(2, pool.length);
    final others = kit.shuffled(pool.where((i) => i.id != widget.target.id && _distinct(i))).take(n - 1);
    _options = kit.shuffled([widget.target, ...others]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play(first: true));
  }

  /// لا نعرض اختيارين متطابقين في الشكل المعروض.
  bool _distinct(GameItem i) => _show(i) != _show(widget.target);

  String _show(GameItem i) => switch (_optField) {
        'label' => i.label,
        'letter' => i.letter ?? i.label,
        'emoji' => i.emoji,
        _ => '${i.emoji}|${i.label}',
      };

  String get _prompt => fillTemplate(lv.strParam('prompt', widget.track.prompt ?? 'أين {label}؟'), widget.target);

  Future<void> _play({bool first = false}) async {
    if (!mounted) return;
    await kit.stop();
    final t = widget.target;
    final speakPrompt = lv.boolParam('speakPrompt', fallback: true);
    if (speakPrompt && (first || t.recite == null)) await kit.sayWait(_prompt);
    if (!mounted || _solved) return;
    if (t.recite != null) {
      await kit.recite(t.recite!);
    } else if (lv.boolParam('sayTarget', fallback: false)) {
      await kit.sayWait(t.spoken);
    }
  }

  Future<void> _pick(GameItem o) async {
    if (_solved || _tried.contains(o.id)) return;
    if (o.id == widget.target.id) {
      setState(() {
        _solved = true;
        _burst++;
        _mood = Art.lamaaCheer;
      });
      kit.good();
      await kit.stop();
      final after = lv.strParam('after', widget.track.params['after'] as String? ?? '{label}');
      await kit.sayWait('${kit.praise()} ${fillTemplate(after, widget.target)}');
      if (mounted) widget.onDone(_tried.length);
    } else {
      setState(() => _tried.add(o.id));
      kit.soft();
      await kit.sayWait(kit.encourage());
      if (mounted && !_solved) await _play();
    }
  }

  PickState _state(GameItem o) {
    if (_solved) return o.id == widget.target.id ? PickState.right : PickState.dim;
    if (_tried.contains(o.id)) return PickState.tried;
    final hintAfter = kit.little ? 1 : 2;
    if (_tried.length >= hintAfter && o.id == widget.target.id) return PickState.hint;
    return PickState.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final big = kit.little || _optField == 'emoji';
    final cols = _options.length == 3 && big ? 3 : 2;
    final cards = [
      for (final o in _options)
        PickCard(
          emoji: _optField == 'label' || _optField == 'letter' ? '' : o.emoji,
          label: switch (_optField) {
            'emoji' => null,
            'letter' => o.letter ?? o.label,
            _ => o.label,
          },
          big: big,
          state: _state(o),
          onTap: () => _pick(o),
        ),
    ];
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(text: _prompt, mood: _mood, trailing: ListenButton(onTap: () => _play(first: true))),
            const SizedBox(height: 14),
            if (_promptShow != 'none')
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text(
                    _promptShow == 'letter' ? (t.letter ?? '') : t.field(_promptShow),
                    style: const TextStyle(fontSize: 84, height: 1.1),
                  ),
                ),
              ),
            PickGrid(columns: cols, children: cards),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}

/// مواقف يومية (الآداب): موقف منطوق + صورته، والطفلة تختار التصرف الجميل.
/// نور: اختياران بالصور. فداء: نص قصير واختيارات أكثر.
class ScenarioRound extends StatefulWidget {
  const ScenarioRound({super.key, required this.scenario, required this.kit, required this.onDone, this.maxOptions = 3});

  final GameScenario scenario;
  final GameKit kit;
  final RoundDone onDone;
  final int maxOptions;

  @override
  State<ScenarioRound> createState() => _ScenarioRoundState();
}

class _ScenarioRoundState extends State<ScenarioRound> {
  late final List<int> _order;
  final Set<int> _tried = {};
  bool _solved = false;
  int _burst = 0;

  GameScenario get s => widget.scenario;
  GameKit get kit => widget.kit;

  @override
  void initState() {
    super.initState();
    final wrong = [for (var i = 0; i < s.options.length; i++) if (i != s.answer) i];
    final keep = kit.shuffled(wrong).take((widget.maxOptions - 1).clamp(1, wrong.length));
    _order = kit.shuffled([s.answer, ...keep]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    await kit.stop();
    await kit.sayWait(s.say);
    if (!kit.little) {
      for (final i in _order) {
        if (!mounted || _solved) return;
        await kit.sayWait(s.options[i].spoken);
      }
    }
  }

  Future<void> _pick(int i) async {
    if (_solved || _tried.contains(i)) return;
    if (i == s.answer) {
      setState(() {
        _solved = true;
        _burst++;
      });
      kit.good();
      await kit.stop();
      await kit.sayWait('${kit.praise()} ${s.options[i].spoken}');
      if (mounted) widget.onDone(_tried.length);
    } else {
      setState(() => _tried.add(i));
      kit.soft();
      await kit.sayWait(kit.encourage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final i in _order)
        PickCard(
          emoji: s.options[i].emoji,
          label: s.options[i].label,
          big: kit.little,
          state: _solved
              ? (i == s.answer ? PickState.right : PickState.dim)
              : _tried.contains(i)
                  ? PickState.tried
                  : (_tried.length >= (kit.little ? 1 : 2) && i == s.answer ? PickState.hint : PickState.neutral),
          onTap: () => _pick(i),
        ),
    ];
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(text: s.text ?? s.say, mood: _solved ? Art.lamaaCheer : Art.lamaaThink, trailing: ListenButton(onTap: _play)),
            const SizedBox(height: 14),
            Center(child: Text(s.emoji, style: const TextStyle(fontSize: 96, height: 1.1))),
            const SizedBox(height: 14),
            PickGrid(columns: _order.length == 3 && kit.little ? 3 : 2, children: cards),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}
