import 'dart:math' as math;

import 'package:flutter/material.dart';

/// حالات «لَمعة»: نجمة صغيرة ودودة، شخصية التطبيق الأصلية.
enum MascotMood {
  /// ابتسامة هادئة (الشاشة الرئيسية).
  happy,

  /// فرحة مع بريق (النجاح والاحتفال).
  cheer,

  /// تفكير (عند بداية سؤال).
  thinking,

  /// تشجيع لطيف (عند الخطأ: «قريب جدًا»).
  encourage,
}

/// لَمعة: تُرسم بالكود (بدون صور) بحركة خفيفة: تمايل بسيط وغمزة عين.
/// حركة واحدة بسيطة داخل RepaintBoundary للحفاظ على الأداء.
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
            builder: (context, _) => CustomPaint(
              painter: _MascotPainter(_controller.value, widget.mood),
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.t, this.mood);

  final double t;
  final MascotMood mood;

  static const Color _body = Color(0xFFFFC94D);
  static const Color _ink = Color(0xFF2B3A4A);
  static const Color _blush = Color(0x66E76F8B);
  static const Color _glint = Color(0x66FFFFFF);
  static const Color _sparkle = Color(0xFFFFE08A);
  static const Color _thought = Color(0xFFB8C4CF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bob = math.sin(t * 2 * math.pi) * s * 0.025;
    final blinking = t > 0.80 && t < 0.84;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + bob);

    // الجسم: نجمة بزوايا مستديرة (تعبئة + حد بنفس اللون بوصلة دائرية).
    final star = _starPath(s * 0.40, s * 0.30);
    canvas.drawPath(
      star,
      Paint()
        ..color = _body
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.12
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(star, Paint()..color = _body);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-s * 0.12, -s * 0.17), width: s * 0.13, height: s * 0.07),
      Paint()..color = _glint,
    );

    // الوجه.
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.026
      ..strokeCap = StrokeCap.round;
    final solidInk = Paint()..color = _ink;
    final faceY = s * 0.03;
    final eyeX = s * 0.105;

    for (final side in [-1.0, 1.0]) {
      final center = Offset(side * eyeX, faceY);
      if (mood == MascotMood.encourage) {
        canvas.drawArc(
          Rect.fromCenter(center: center, width: s * 0.085, height: s * 0.085),
          math.pi,
          math.pi,
          false,
          ink,
        );
      } else if (blinking) {
        canvas.drawLine(
          center + Offset(-s * 0.04, 0),
          center + Offset(s * 0.04, 0),
          ink,
        );
      } else {
        final r = mood == MascotMood.cheer ? s * 0.048 : s * 0.04;
        canvas.drawCircle(center, r, solidInk);
        canvas.drawCircle(
          center + Offset(r * 0.35, -r * 0.35),
          r * 0.35,
          Paint()..color = Colors.white,
        );
      }
    }

    // الخدود.
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(side * s * 0.17, faceY + s * 0.06), s * 0.04, Paint()..color = _blush);
    }

    // الفم والتفاصيل حسب الحالة.
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.encourage:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(0, faceY + s * 0.05), width: s * 0.16, height: s * 0.10),
          math.pi * 0.15,
          math.pi * 0.7,
          false,
          ink,
        );
      case MascotMood.cheer:
        final mouth = Rect.fromCenter(
          center: Offset(0, faceY + s * 0.045),
          width: s * 0.15,
          height: s * 0.14,
        );
        canvas.drawPath(Path()..addArc(mouth, 0, math.pi)..close(), solidInk);
        canvas.drawCircle(
          Offset(0, faceY + s * 0.098),
          s * 0.025,
          Paint()..color = const Color(0xFFE76F8B),
        );
      case MascotMood.thinking:
        canvas.drawCircle(Offset(s * 0.04, faceY + s * 0.085), s * 0.018, solidInk);
        canvas.drawLine(
          Offset(eyeX - s * 0.03, faceY - s * 0.07),
          Offset(eyeX + s * 0.05, faceY - s * 0.09),
          ink,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(s * (0.30 + i * 0.07), -s * (0.30 + i * 0.07)),
            s * (0.012 + i * 0.008),
            Paint()..color = _thought,
          );
        }
    }

    // بريق يتلألأ عند الفرح.
    if (mood == MascotMood.cheer) {
      final spots = [
        Offset(-s * 0.40, -s * 0.38),
        Offset(s * 0.42, -s * 0.32),
        Offset(s * 0.44, s * 0.30),
      ];
      final radii = [s * 0.07, s * 0.06, s * 0.045];
      for (var i = 0; i < spots.length; i++) {
        final k = 0.65 + 0.35 * math.sin(t * 4 * math.pi + i * 2);
        canvas.drawPath(_sparklePath(spots[i], radii[i] * k), Paint()..color = _sparkle);
      }
    }

    canvas.restore();
  }

  Path _starPath(double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  Path _sparklePath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.3;
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.t != t || old.mood != mood;
}
