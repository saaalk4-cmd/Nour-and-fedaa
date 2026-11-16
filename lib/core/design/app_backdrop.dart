import 'dart:math' as math;

import 'package:flutter/material.dart';

/// خلفية التطبيق الموحّدة: سماء ناعمة، شمس مضيئة، سحب تتحرك ببطء، وتلال خضراء في الأسفل.
/// تُرسم بالكود (بلا صور) وتُوضع مرة واحدة خلف كل الشاشات؛ الـ Scaffold شفاف فوقها.
class AppBackdrop extends StatefulWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(painter: BackdropPainter(_drift.value)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class BackdropPainter extends CustomPainter {
  BackdropPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // السماء.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9E3F9), Color(0xFFDDF2FD), Color(0xFFFFF7E6)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // الشمس بتوهج ناعم.
    final sun = Offset(w * 0.84, h * 0.09);
    canvas.drawCircle(
      sun,
      w * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x66FFE49A), const Color(0x00FFE49A)],
        ).createShader(Rect.fromCircle(center: sun, radius: w * 0.34)),
    );
    canvas.drawCircle(sun, w * 0.075, Paint()..color = const Color(0xFFFFD66B));

    // سحب تنجرف ببطء (3 سحب بسرعات مختلفة).
    _cloud(canvas, w, h * 0.12, 0.18, t, 1.0, 0.85);
    _cloud(canvas, w, h * 0.30, 0.12, t + 0.35, 0.7, 0.7);
    _cloud(canvas, w, h * 0.52, 0.2, t + 0.7, 0.85, 0.55);

    // نجوم صغيرة باهتة.
    final star = Paint()..color = const Color(0x55FFFFFF);
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.6), 1.6 + rnd.nextDouble() * 1.4, star);
    }

    // التلال في الأسفل.
    _hill(canvas, size, h * 0.9, 18, const Color(0xFFCDEBC0), 0.0);
    _hill(canvas, size, h * 0.94, 14, const Color(0xFFB4E0A8), 1.2);
  }

  void _cloud(Canvas canvas, double w, double y, double scale, double phase, double speed, double opacity) {
    final p = Paint()..color = Colors.white.withValues(alpha: opacity);
    final span = w * 1.6;
    final x = ((phase * speed) % 1.0) * span - w * 0.3;
    final r = w * scale * 0.5;
    canvas.drawCircle(Offset(x, y), r * 0.55, p);
    canvas.drawCircle(Offset(x + r * 0.55, y - r * 0.18), r * 0.7, p);
    canvas.drawCircle(Offset(x + r * 1.15, y), r * 0.5, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - r * 0.55, y, r * 2.2, r * 0.55),
        Radius.circular(r * 0.3),
      ),
      p,
    );
  }

  void _hill(Canvas canvas, Size size, double top, double amp, Color color, double phase) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, top);
    for (var x = 0.0; x <= size.width; x += 8) {
      path.lineTo(x, top + math.sin(x / size.width * 2 * math.pi + phase) * amp);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BackdropPainter old) => old.t != t;
}

/// انتقال الصفحات: كل صفحة تحمل خلفيتها الخاصة (فلا تتداخل الصفحتان أثناء الانتقال)
/// مع تلاشٍ وانزلاق خفيف للأعلى.
class BackdropPageTransitions extends PageTransitionsBuilder {
  const BackdropPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: AppBackdrop(child: child),
      ),
    );
  }
}
