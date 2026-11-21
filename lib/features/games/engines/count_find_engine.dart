import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/art.dart';
import '../../../core/design/kit.dart';
import '../../../core/design/pop_tap.dart';
import '../../../core/theme/app_theme.dart';
import '../game_content.dart';
import '../game_kit.dart';
import '../../../core/design/emoji_art.dart';

const numberWords = ['صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة'];

/// العدّ. نور: «اضغطي على 3 نجوم» وكل ضغطة تُعدّ بصوت عالٍ. فداء: تعدّ وتختار الرقم الصحيح.
class CountRound extends StatefulWidget {
  const CountRound({super.key, required this.thing, required this.n, required this.kit, required this.onDone, required this.tapMode, this.extra = 2});

  final GameItem thing;
  final int n;
  final GameKit kit;
  final RoundDone onDone;
  final bool tapMode;

  /// نور: عدد الأشياء الزائدة عن المطلوب (لتختار هي كم تضغط).
  final int extra;

  @override
  State<CountRound> createState() => _CountRoundState();
}

class _CountRoundState extends State<CountRound> {
  final Set<int> _tapped = {};
  late final List<int> _choices;
  final Set<int> _tried = {};
  bool _done = false;
  int _burst = 0;

  GameKit get kit => widget.kit;
  int get _shown => widget.tapMode ? widget.n + widget.extra : widget.n;
  String get _prompt => widget.tapMode ? 'عُدّي واضغطي حتى ${numberWords[widget.n]}' : 'كم ${widget.thing.label} هنا؟';

  @override
  void initState() {
    super.initState();
    final n = widget.n;
    final opts = <int>{n};
    var d = 1;
    while (opts.length < 3) {
      if (n - d >= 1) opts.add(n - d);
      if (opts.length < 3 && n + d <= 10) opts.add(n + d);
      d++;
    }
    _choices = kit.shuffled(opts);
    WidgetsBinding.instance.addPostFrameCallback((_) => kit.sayWait(_prompt));
  }

  Future<void> _tap(int i) async {
    if (!widget.tapMode || _done || _tapped.contains(i)) return;
    setState(() => _tapped.add(i));
    kit.soft();
    await kit.say(numberWords[_tapped.length]);
    if (_tapped.length == widget.n) {
      setState(() {
        _done = true;
        _burst++;
      });
      kit.good();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await kit.sayWait('${kit.praise()} ${numberWords[widget.n]}');
      if (mounted) widget.onDone(0);
    }
  }

  Future<void> _choose(int v) async {
    if (_done || _tried.contains(v)) return;
    if (v == widget.n) {
      setState(() {
        _done = true;
        _burst++;
      });
      kit.good();
      await kit.sayWait('${kit.praise()} ${numberWords[v]}');
      if (mounted) widget.onDone(_tried.length);
    } else {
      setState(() => _tried.add(v));
      kit.soft();
      await kit.sayWait('${kit.encourage()}، عُدّي معي');
      for (var k = 1; k <= widget.n && mounted && !_done; k++) {
        await kit.sayWait(numberWords[k]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(text: _prompt, mood: _done ? Art.lamaaCheer : Art.lamaaPoint, trailing: ListenButton(onTap: () => kit.sayWait(_prompt))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(28), border: Border.all(color: Wood.dark, width: 3)),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _shown; i++)
                    PopTap(
                      onTap: widget.tapMode ? () => _tap(i) : null,
                      child: AnimatedScale(
                        scale: _tapped.contains(i) ? 1.18 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: kit.little ? 82 : 66,
                          height: kit.little ? 82 : 66,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _tapped.contains(i) ? const Color(0xFFFFF0B3) : Colors.transparent,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              EmojiPic(widget.thing.emoji, size: kit.little ? 54 : 44),
                              if (_tapped.contains(i))
                                PositionedDirectional(
                                  bottom: 0,
                                  end: 0,
                                  child: Text('${_tapped.toList().indexOf(i) + 1}', style: AppText.display(22, color: const Color(0xFFE07B1F))),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!widget.tapMode)
              PickGrid(columns: 3, children: [
                for (final v in _choices)
                  PickCard(
                    emoji: '',
                    label: '$v\n${numberWords[v]}',
                    state: _done
                        ? (v == widget.n ? PickState.right : PickState.dim)
                        : (_tried.contains(v) ? PickState.tried : PickState.neutral),
                    onTap: () => _choose(v),
                  ),
              ]),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}

/// «فين المستخبي؟»: مشهد من رموز، والطفلة تجد المطلوب. نور: شيء واحد بين قليل. فداء: عدة أشياء بين كثير.
class FindRound extends StatefulWidget {
  const FindRound({super.key, required this.target, required this.distractors, required this.kit, required this.onDone, required this.cells, required this.targets});

  final GameItem target;
  final List<String> distractors;
  final GameKit kit;
  final RoundDone onDone;
  final int cells;
  final int targets;

  @override
  State<FindRound> createState() => _FindRoundState();
}

class _FindRoundState extends State<FindRound> {
  late final List<String> _scene;
  final Set<int> _found = {};
  final Set<int> _miss = {};
  bool _done = false;
  int _burst = 0;

  GameKit get kit => widget.kit;
  String get _prompt => widget.targets == 1 ? 'أين ${widget.target.label}؟' : 'ابحثي عن كل ${widget.target.label} في الحديقة';

  @override
  void initState() {
    super.initState();
    final others = [for (final d in widget.distractors) if (d != widget.target.emoji) d];
    final cells = <String>[for (var i = 0; i < widget.targets; i++) widget.target.emoji];
    while (cells.length < widget.cells) {
      cells.add(others[kit.rng.nextInt(others.length)]);
    }
    _scene = kit.shuffled(cells);
    WidgetsBinding.instance.addPostFrameCallback((_) => kit.sayWait(_prompt));
  }

  Future<void> _tap(int i) async {
    if (_done || _found.contains(i)) return;
    if (_scene[i] == widget.target.emoji) {
      setState(() => _found.add(i));
      kit.good();
      if (_found.length == widget.targets) {
        setState(() {
          _done = true;
          _burst++;
        });
        await kit.sayWait('${kit.praise()} وجدتِها');
        if (mounted) widget.onDone(_miss.length > 1 ? _miss.length - 1 : 0);
      } else {
        unawaited(kit.say(numberWords[_found.length]));
      }
    } else {
      setState(() => _miss.add(i));
      kit.soft();
      await kit.sayWait(kit.encourage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.cells <= 6 ? 3 : 4;
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(text: _prompt, mood: _done ? Art.lamaaCheer : Art.lamaaThink, trailing: ListenButton(onTap: () => kit.sayWait(_prompt))),
            const SizedBox(height: 10),
            Center(child: EmojiPic(widget.target.emoji, size: 48)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDFF5FF), Color(0xFFCFEFC4)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Wood.dark, width: 3),
              ),
              child: GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < _scene.length; i++)
                    PopTap(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _found.contains(i) ? const Color(0xFFCDF3C2) : Colors.transparent,
                          border: _found.contains(i) ? Border.all(color: const Color(0xFF3F8F2F), width: 3) : null,
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: _miss.contains(i) ? 0.35 : 1,
                            child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: Text(_scene[i], style: const TextStyle(fontSize: 44)))),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}
