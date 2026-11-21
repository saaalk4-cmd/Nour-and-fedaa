import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// يلفّ أي عنصر بحركة «ضغطة» لطيفة (تصغير بسيط عند اللمس) واهتزاز خفيف: إحساس الألعاب.
class PopTap extends StatefulWidget {
  const PopTap({super.key, required this.child, required this.onTap, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<PopTap> createState() => _PopTapState();
}

class _PopTapState extends State<PopTap> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
