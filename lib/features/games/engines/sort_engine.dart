import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/art.dart';
import '../../../core/design/kit.dart';
import '../../../core/theme/app_theme.dart';
import '../game_content.dart';
import '../game_kit.dart';

/// الفرز في السلال (ألوان، أشكال، أنواع). نور: عنصر واحد تضغط سلّته (سلتان).
/// فداء: تسحب كل العناصر إلى سلالها (حتى 3 سلال).
class SortRound extends StatefulWidget {
  const SortRound({super.key, required this.items, required this.groups, required this.kit, required this.onDone, required this.drag, required this.prompt});

  final List<GameItem> items;
  final List<GameGroup> groups;
  final GameKit kit;
  final RoundDone onDone;
  final bool drag;
  final String prompt;

  @override
  State<SortRound> createState() => _SortRoundState();
}

class _SortRoundState extends State<SortRound> {
  late final List<GameItem> _queue = widget.kit.shuffled(widget.items);
  final Map<String, List<GameItem>> _inBin = {};
  int _slips = 0;
  String? _shakeBin;
  int _burst = 0;

  GameKit get kit => widget.kit;
  List<GameItem> get _left => [for (final i in _queue) if (!_inBin.values.any((l) => l.contains(i))) i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => kit.sayWait(widget.prompt));
  }

  Future<void> _drop(GameItem item, GameGroup bin) async {
    if (item.group == bin.id) {
      setState(() => (_inBin[bin.id] ??= []).add(item));
      kit.good();
      unawaited(kit.say(item.spoken));
      if (_left.isEmpty) {
        setState(() => _burst++);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await kit.sayWait('${kit.praise()} كل شيء في مكانه');
        if (mounted) widget.onDone(_slips > 1 ? _slips - 1 : 0);
      }
    } else {
      setState(() {
        _slips++;
        _shakeBin = bin.id;
      });
      kit.soft();
      await kit.sayWait(kit.encourage());
      if (mounted) setState(() => _shakeBin = null);
    }
  }

  Widget _itemCard(GameItem i) => PickCard(emoji: i.emoji, big: kit.little, onTap: () => kit.say(i.spoken));

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final current = left.isEmpty ? null : left.first;
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(text: widget.prompt, mood: left.isEmpty ? Art.lamaaCheer : Art.lamaaPoint),
            const SizedBox(height: 14),
            if (!widget.drag && current != null)
              Center(child: SizedBox(width: 170, child: KeyedSubtree(key: ValueKey(current.id), child: _itemCard(current))))
            else if (widget.drag)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final i in left)
                    Draggable<GameItem>(
                      data: i,
                      feedback: Material(color: Colors.transparent, child: Text(i.emoji, style: const TextStyle(fontSize: 64))),
                      childWhenDragging: const SizedBox(width: 96, height: 96),
                      child: SizedBox(width: 96, child: _itemCard(i)),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (final g in widget.groups) ...[
                  if (g != widget.groups.first) const SizedBox(width: 10),
                  Expanded(
                    child: _Bin(
                      group: g,
                      count: (_inBin[g.id] ?? const []).length,
                      shaking: _shakeBin == g.id,
                      items: _inBin[g.id] ?? const [],
                      onTap: !widget.drag && current != null ? () => _drop(current, g) : null,
                      onAccept: widget.drag ? (i) => _drop(i, g) : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}

class _Bin extends StatelessWidget {
  const _Bin({required this.group, required this.count, required this.shaking, required this.items, this.onTap, this.onAccept});

  final GameGroup group;
  final int count;
  final bool shaking;
  final List<GameItem> items;
  final VoidCallback? onTap;
  final void Function(GameItem)? onAccept;

  @override
  Widget build(BuildContext context) {
    final c = group.color == null ? Wood.mid : Color(group.color!);
    Widget body(bool hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(shaking ? 6 : 0, 0, 0),
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hover ? Color.lerp(c, Colors.white, 0.6) : Color.lerp(c, Colors.white, 0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(34)),
            border: Border.all(color: Color.lerp(c, Colors.black, 0.3)!, width: 4),
          ),
          child: Column(
            children: [
              Text(group.emoji, style: const TextStyle(fontSize: 40)),
              Text(group.label, textAlign: TextAlign.center, style: AppText.display(20, color: Color.lerp(c, Colors.black, 0.55)!)),
              const SizedBox(height: 4),
              Wrap(spacing: 2, runSpacing: 2, alignment: WrapAlignment.center, children: [
                for (final i in items) Text(i.emoji, style: const TextStyle(fontSize: 22)),
              ]),
            ],
          ),
        );
    final accept = onAccept;
    if (accept != null) {
      return DragTarget<GameItem>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => accept(d.data),
        builder: (context, cands, _) => body(cands.isNotEmpty),
      );
    }
    return GestureDetector(onTap: onTap, child: body(false));
  }
}
