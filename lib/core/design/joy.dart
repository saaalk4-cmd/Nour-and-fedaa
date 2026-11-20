import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';
import 'kit.dart';

/// درجات الاحتفال: صغيرة (إجابة صحيحة)، متوسطة (3 ورا بعض)، كبيرة (إنهاء مستوى أو درس).
enum JoyLevel { small, medium, big }

/// احتفال مبهج وقصير: كونفيتي ناعم ولَمعة ترقص وعبارة. يختفي وحده ولا يلمس الشاشة.
/// [calm] (قرآن وأذكار): لمعة نجمة هادئة فقط. [reduceMotion]: بلا حركة، عبارة قصيرة فقط.
class JoyBurst extends StatefulWidget {
  const JoyBurst({super.key, required this.level, this.text, this.calm = false, this.reduceMotion = false});

  final JoyLevel level;
  final String? text;
  final bool calm;
  final bool reduceMotion;

  /// مدة ظهوره (ليخفيه من يعرضه بعدها).
  static const duration = Duration(milliseconds: 2400);

  @override
  State<JoyBurst> createState() => _JoyBurstState();
}

class _JoyBurstState extends State<JoyBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: JoyBurst.duration)..forward();
  late final List<_Piece> _pieces = _makePieces(widget.level == JoyLevel.big ? 46 : 28);

  @override
  void initState() {
    super.initState();
    if (widget.level != JoyLevel.small) HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static List<_Piece> _makePieces(int n) {
    final r = math.Random(11);
    const colors = [Color(0xFFFFC21F), Color(0xFFFF8FB1), Color(0xFF7ED36B), Color(0xFF5AA9F0), Color(0xFFB98CFF), Color(0xFFFF9F43)];
    return [
      for (var i = 0; i < n; i++)
        _Piece(
          x: r.nextDouble(),
          delay: r.nextDouble() * 0.35,
          speed: 0.55 + r.nextDouble() * 0.4,
          sway: (r.nextDouble() - 0.5) * 0.18,
          size: 7 + r.nextDouble() * 8,
          spin: r.nextDouble() * 6,
          color: colors[i % colors.length],
          star: i % 5 == 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final still = widget.reduceMotion;
    final calm = widget.calm;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fade = t < 0.1 ? t / 0.1 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!still && !calm && widget.level != JoyLevel.small)
                  CustomPaint(painter: _ConfettiPainter(_pieces, t)),
                Align(
                  alignment: const Alignment(0, 0.35),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (text != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Wood.cream,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Wood.dark, width: 3),
                            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Wood.text)),
                        ),
                      _dancer(t, still, calm),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dancer(double t, bool still, bool calm) {
    if (calm) {
      // هادئ: نجمة تنبض بلطف، بلا رقص.
      final s = 1 + 0.12 * math.sin(t * math.pi * 3);
      return Transform.scale(scale: s, child: const ArtImage(Art.starOn, width: 84, height: 84));
    }
    final size = widget.level == JoyLevel.small ? 80.0 : 120.0;
    if (still) return ArtImage(Art.lamaaCheer, width: size, height: size);
    final bounce = -(math.sin(t * math.pi * 6)).abs() * 22;
    final tilt = math.sin(t * math.pi * 6) * 0.12;
    return Transform.translate(
      offset: Offset(0, bounce),
      child: Transform.rotate(angle: tilt, child: ArtImage(Art.lamaaCheer, width: size, height: size)),
    );
  }
}

class _Piece {
  const _Piece({required this.x, required this.delay, required this.speed, required this.sway, required this.size, required this.spin, required this.color, required this.star});

  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double size;
  final double spin;
  final Color color;
  final bool star;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final k = ((t - p.delay) / p.speed).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final y = -20 + (size.height * 0.9) * Curves.easeIn.transform(k);
      final x = size.width * (p.x + math.sin(k * 6 + p.spin) * p.sway);
      final paint = Paint()..color = p.color.withValues(alpha: (1 - k * 0.6).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin + k * 8);
      if (p.star) {
        final path = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final b = a + math.pi / 5;
          final o = Offset(math.cos(a), math.sin(a)) * p.size;
          final inn = Offset(math.cos(b), math.sin(b)) * p.size * 0.45;
          if (i == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
          path.lineTo(inn.dx, inn.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
