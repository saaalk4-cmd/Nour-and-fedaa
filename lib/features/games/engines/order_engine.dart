import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/art.dart';
import '../../../core/design/kit.dart';
import '../../../core/theme/app_theme.dart';
import '../game_content.dart';
import '../game_kit.dart';

/// ترتيب الخطوات (الوضوء، الصلاة، آيات سورة…).
/// نور: تضغط البطاقة التالية فتنتقل للطريق (بطاقتان أو ثلاث). فداء: تسحب كل بطاقة إلى خانتها المرقّمة.
class OrderRound extends StatefulWidget {
  const OrderRound({super.key, required this.steps, required this.kit, required this.onDone, required this.drag, required this.prompt});

  /// الخطوات بالترتيب الصحيح.
  final List<GameItem> steps;
  final GameKit kit;
  final RoundDone onDone;
  final bool drag;
  final String prompt;

  @override
  State<OrderRound> createState() => _OrderRoundState();
}

class _OrderRoundState extends State<OrderRound> {
  late final List<GameItem> _deck = widget.kit.shuffled(widget.steps);
  final List<GameItem> _placed = [];
  int _slips = 0;
  String? _shaking;
  int _burst = 0;
  bool _done = false;

  GameKit get kit => widget.kit;
  GameItem? get _next => _placed.length < widget.steps.length ? widget.steps[_placed.length] : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => kit.sayWait(widget.prompt));
  }

  Future<void> _hear(GameItem s) async {
    await kit.stop();
    if (s.recite != null) {
      await kit.recite(s.recite!);
    } else {
      await kit.sayWait(s.spoken);
    }
  }

  Future<void> _try(GameItem s, {int? slot}) async {
    if (_done || _placed.contains(s)) return;
    final want = _next;
    final rightSlot = slot == null || slot == _placed.length;
    if (want != null && s.id == want.id && rightSlot) {
      setState(() => _placed.add(s));
      kit.good();
      unawaited(_hear(s));
      if (_placed.length == widget.steps.length) {
        setState(() {
          _done = true;
          _burst++;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await kit.stop();
        await kit.sayWait('${kit.praise()} رتّبتِ كل الخطوات');
        if (mounted) widget.onDone(_slips > 1 ? _slips - 1 : 0);
      }
    } else {
      setState(() {
        _slips++;
        _shaking = s.id;
      });
      kit.soft();
      if (_slips >= 2 && want != null && want.recite != null) {
        // آية: لا تُنطق آليًا أبدًا؛ نسمعها بصوت الشيخ.
        await kit.sayWait('اسمعي الآية التالية');
        await kit.recite(want.recite!);
      } else {
        await kit.sayWait(_slips >= 2 && want != null ? 'نبدأ بـ ${want.spoken}' : kit.encourage());
      }
      if (mounted) setState(() => _shaking = null);
    }
  }

  Widget _card(GameItem s, {bool small = false}) {
    final hint = !_done && _slips >= 2 && _next?.id == s.id;
    return PickCard(
      key: ValueKey('card-${s.id}'),
      emoji: s.emoji,
      label: kit.little && !widget.drag ? null : s.label,
      big: kit.little && !small,
      state: _shaking == s.id ? PickState.tried : (hint ? PickState.hint : PickState.neutral),
      onTap: widget.drag ? () => _hear(s) : () => _try(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.steps.length;
    final remaining = [for (final s in _deck) if (!_placed.contains(s)) s];
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GamePrompt(
              text: widget.prompt,
              mood: _done ? Art.lamaaCheer : Art.lamaaPoint,
              trailing: ListenButton(onTap: () => kit.sayWait(widget.prompt)),
            ),
            const SizedBox(height: 14),
            // الطريق: خانات مرقّمة تمتلئ بالترتيب.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < n; i++)
                  _Slot(
                    index: i,
                    filled: i < _placed.length ? _placed[i] : null,
                    active: i == _placed.length,
                    width: n <= 3 ? 104 : 86,
                    onAccept: widget.drag ? (s) => _try(s, slot: i) : null,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (remaining.isNotEmpty)
              PickGrid(
                columns: kit.little ? (remaining.length >= 3 ? 3 : 2) : 3,
                children: [
                  for (final s in remaining)
                    widget.drag
                        ? Draggable<GameItem>(
                            data: s,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(width: 110, child: _card(s, small: true)),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: _card(s)),
                            child: _card(s),
                          )
                        : _card(s),
                ],
              ),
            if (widget.drag && remaining.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('اسحبي كل بطاقة إلى رقمها', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Wood.text)),
              ),
          ],
        ),
        StarBurst(trigger: _burst),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.filled, required this.active, required this.width, this.onAccept});

  final int index;
  final GameItem? filled;
  final bool active;
  final double width;
  final void Function(GameItem)? onAccept;

  @override
  Widget build(BuildContext context) {
    Widget box(bool hovering) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: width,
          decoration: BoxDecoration(
            color: filled != null ? const Color(0xFFCDF3C2) : (hovering ? const Color(0xFFFFF0B3) : Colors.white.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: active ? const Color(0xFFE07B1F) : Wood.dark, width: active ? 4 : 3),
          ),
          child: filled == null
              ? Center(child: Text('${index + 1}', style: AppText.display(34, color: Wood.dark)))
              : Stack(
                  children: [
                    Center(child: FittedBox(child: Padding(padding: const EdgeInsets.all(8), child: Text(filled!.emoji, style: const TextStyle(fontSize: 46))))),
                    PositionedDirectional(
                      top: 4,
                      start: 6,
                      child: Text('${index + 1}', style: AppText.display(18, color: const Color(0xFF3F8F2F))),
                    ),
                  ],
                ),
        );
    final accept = onAccept;
    if (accept == null || filled != null) return box(false);
    return DragTarget<GameItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => accept(d.data),
      builder: (context, candidates, _) => box(candidates.isNotEmpty),
    );
  }
}
