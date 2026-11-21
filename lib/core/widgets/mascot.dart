import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/art.dart';

/// حالات «لَمعة»: نجمة صغيرة ودودة، شخصية التطبيق الأصلية.
enum MascotMood {
  /// ابتسامة هادئة (الشاشة الرئيسية).
  happy,

  /// فرحة مع بريق (النجاح والاحتفال).
  cheer,

  /// تفكير (عند بداية سؤال).
  thinking,

  /// تشجيع لطيف (مرحّبة بذراعين مفتوحتين).
  encourage,
}

/// اسم صورة لَمعة المناسبة للحالة.
String mascotArt(MascotMood mood) {
  switch (mood) {
    case MascotMood.happy:
      return Art.lamaaCalm;
    case MascotMood.cheer:
      return Art.lamaaCheer;
    case MascotMood.thinking:
      return Art.lamaaThink;
    case MascotMood.encourage:
      return Art.lamaaWelcome;
  }
}

/// لَمعة بالصورة المعتمدة (وضعية لكل حالة) مع تمايل خفيف.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.size = 120, this.mood = MascotMood.happy});

  final double size;
  final MascotMood mood;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'لَمعة',
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_controller.value * 2 * math.pi) * widget.size * 0.03),
              child: child,
            ),
            child: ArtImage(mascotArt(widget.mood), width: widget.size, height: widget.size),
          ),
        ),
      ),
    );
  }
}
