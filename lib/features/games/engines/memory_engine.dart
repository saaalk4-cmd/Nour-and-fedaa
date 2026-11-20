import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/art.dart';
import '../../../core/design/kit.dart';
import '../../../core/design/pop_tap.dart';
import '../../../core/theme/app_theme.dart';
import '../game_content.dart';
import '../game_kit.dart';

/// كروت الذاكرة. نور: صورة مع نفس الصورة (4 كروت كبيرة). فداء: صورة مع كلمتها (8–12 كارتًا).
class MemoryRound extends StatefulWidget {
  const MemoryRound({super.key, required this.items, required this.kit, required this.onDone, required this.words});

  final List<GameItem> items;
  final GameKit kit;
  final RoundDone onDone;

  /// فداء: نصف الكروت كلمات.
  final bool words;

  @override
  State<MemoryRound> createState() => _MemoryRoundState();
}

class _Face {
  _Face(this.item, this.word);
  final GameItem item;
  final bool word;
}

class _MemoryRoundState extends State<MemoryRound> {
  late final List<_Face> _cards;
  final Set<int> _open = {};
  final Set<int> _matched = {};
  int _misses = 0;
  bool _busy = false;
  int _burst = 0;

  GameKit get kit => widget.kit;

  @override
  void initState() {
    super.initState();
    _cards = kit.shuffled([
      for (final i in widget.items) ...[_Face(i, false), _Face(i, widget.words)],
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => kit.sayWait(widget.words ? 'اقلبي كارتين: الصورة وكلمتها' : 'اقلبي كارتين متشابهين'));
  }

  Future<void> _flip(int i) async {
    if (_busy || _open.contains(i) || _matched.contains(i)) return;
    setState(() => _open.add(i));
    kit.soft();
    unawaited(kit.say(_cards[i].item.spoken));
    if (_open.length < 2) return;
    _busy = true;
    final [a, b] = _open.toList();
    if (_cards[a].item.id == _cards[b].item.id) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      setState(() {
        _matched.addAll([a, b]);
        _open.clear();
        _burst++;
      });
      kit.good();
      if (_matched.length == _cards.length) {
        await kit.sayWait('${kit.praise()} وجدتِ كل الأزواج');
        if (mounted) widget.onDone(math.max(0, _misses - widget.items.length));
      }
    } else {
      _misses++;
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (mounted) setState(_open.clear);
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final n = _cards.length;
    final cols = n <= 4 ? 2 : (n <= 9 ? 3 : 4);
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(
              text: widget.words ? 'اقلبي كارتين: الصورة وكلمتها' : 'اقلبي كارتين متشابهين',
              mood: _matched.length == n ? Art.lamaaCheer : Art.lamaaThink,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 0; i < n; i++)
                  _MemoryCard(
                    face: _cards[i],
                    open: _open.contains(i) || _matched.contains(i),
                    matched: _matched.contains(i),
                    onTap: () => _flip(i),
                  ),
              ],
            ),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.face, required this.open, required this.matched, required this.onTap});

  final _Face face;
  final bool open;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PopTap(
      onTap: open ? null : onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: open ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        builder: (context, t, _) {
          final showFront = t >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(math.pi * t),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(showFront ? math.pi : 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: showFront
                      ? null
                      : const LinearGradient(colors: [Color(0xFFB98CFF), Color(0xFF7A55D6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  color: showFront ? (matched ? const Color(0xFFCDF3C2) : Wood.cream) : null,
                  border: Border.all(color: showFront ? Wood.dark : Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 4), blurRadius: 4)],
                ),
                child: Center(
                  child: showFront
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: FittedBox(
                            child: face.word
                                ? Text(face.item.label, style: AppText.display(30, color: Wood.text))
                                : Text(face.item.emoji, style: const TextStyle(fontSize: 54)),
                          ),
                        )
                      : const ArtImage(Art.starOn, width: 40, height: 40),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
