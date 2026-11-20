import 'package:flutter/material.dart';

import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';

/// محطة على الخريطة: قسم بصورته واسمه.
class MapStop {
  const MapStop({required this.art, required this.title, required this.color, required this.onTap});

  final String art;
  final String title;
  final Color color;
  final VoidCallback onTap;
}

/// «عالمي» كخريطة مرسومة: طريق متعرّج بين خلفيات العالم، والأقسام محطات عليه يمين وشمال.
/// اختياري من لوحة الأهل (البديل: شبكة المربعات).
class WorldMap extends StatelessWidget {
  const WorldMap({super.key, required this.stops});

  final List<MapStop> stops;

  static const double step = 150;
  static const double top = 80;

  /// مركز المحطة [i] بالنسبة لعرض [w].
  static Offset centerOf(int i, double w) => Offset(w * (i.isEven ? 0.30 : 0.70), top + i * step);

  static double heightFor(int n) => top + (n - 1).clamp(0, 999) * step + 130;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = heightFor(stops.length);
      final segH = w * 1024 / 765;
      final bgs = [Art.bgPath, Art.bgForest, Art.bgRiver];
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(children: [
            // الخلفيات فوق بعض بطول الخريطة.
            for (var k = 0; k * segH < h; k++)
              Positioned(left: 0, right: 0, top: k * segH, height: segH, child: ArtImage(bgs[k % bgs.length], fit: BoxFit.cover)),
            Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.12))),
            // زينة على الجوانب.
            for (var i = 0; i < stops.length; i++)
              Positioned(
                left: i.isEven ? w * 0.70 : w * 0.06,
                top: WorldMap.centerOf(i, w).dy - 30,
                width: w * 0.22,
                height: w * 0.22,
                child: IgnorePointer(child: ArtImage(Art.decor[i % Art.decor.length], fit: BoxFit.contain)),
              ),
            Positioned.fill(child: CustomPaint(painter: _TrailPainter(count: stops.length))),
            for (var i = 0; i < stops.length; i++) _stop(i, w),
          ]),
        ),
      );
    });
  }

  Widget _stop(int i, double w) {
    final s = stops[i];
    final c = centerOf(i, w);
    const d = 92.0;
    return Positioned(
      left: c.dx - 70,
      top: c.dy - d / 2,
      width: 140,
      child: Semantics(
        button: true,
        label: s.title,
        excludeSemantics: true,
        child: PopTap(
          onTap: s.onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: d,
              height: d,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: s.color, width: 6),
                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: ArtImage(s.art, fit: BoxFit.contain),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: OutlineText(s.title, size: 22, stroke: Color.lerp(s.color, Colors.black, 0.4)!, maxLines: 1),
            ),
          ]),
        ),
      ),
    );
  }
}

/// الطريق: خط منقّط متعرّج يمر بمراكز المحطات.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.count});

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final path = Path();
    final p0 = WorldMap.centerOf(0, size.width);
    path.moveTo(p0.dx, p0.dy);
    for (var i = 1; i < count; i++) {
      final a = WorldMap.centerOf(i - 1, size.width);
      final b = WorldMap.centerOf(i, size.width);
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final road = Paint()
      ..color = const Color(0xFFF6E2B3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFC98E4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, edge);
    canvas.drawPath(path, road);
    // نقاط على الطريق.
    final dots = Paint()..color = Colors.white;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 26) {
        final t = m.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 3.5, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.count != count;
}

