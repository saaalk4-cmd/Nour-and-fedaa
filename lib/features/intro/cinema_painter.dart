import 'dart:math' as math;

import 'package:flutter/material.dart';

/// مدة المقدمة السينمائية بالثواني، وحدود المشاهد السبعة (انظر docs/CINEMATIC.md).
const double kCinemaSeconds = 45;
const List<double> kCinemaShots = [0, 5, 10, 15, 22, 30, 38, 45];

/// لحظات الصوت (موسيقى/مؤثرات) لتُربط لاحقًا دون تعديل الرسم.
class CinemaCue {
  const CinemaCue(this.t, this.name);
  final double t;
  final String name;
}

const List<CinemaCue> kCinemaCues = [
  CinemaCue(0.5, 'first_light'),
  CinemaCue(5, 'descend'),
  CinemaCue(10, 'lamaa'),
  CinemaCue(15, 'sisters'),
  CinemaCue(23, 'map_appears'),
  CinemaCue(31, 'star_to_nour'),
  CinemaCue(35, 'star_to_fedaa'),
  CinemaCue(39, 'portals_open'),
];

/// رقم المشهد (1–7) عند الزمن [t].
int cinemaShotAt(double t) {
  for (var i = kCinemaShots.length - 2; i >= 0; i--) {
    if (t >= kCinemaShots[i]) return i + 1;
  }
  return 1;
}

/// تقدّم من 0 إلى 1 بين [a] و[b].
double cinemaRamp(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

double _ease(double x) => x * x * (3 - 2 * x);
double _lerp(double a, double b, double x) => a + (b - a) * x;

/// ترسم المقدمة بالكود فقط (بلا صور ولا نصوص): عالم واحد مشترك،
/// ورحلتان مختلفتان لفداء ونور، ولَمعة دليلًا بينهما. لا تُرسم أي شخصية دينية.
class CinemaPainter extends CustomPainter {
  CinemaPainter(this.t);

  final double t;

  static final List<Offset> _stars = _genStars();
  static List<Offset> _genStars() {
    final r = math.Random(7);
    return [for (var i = 0; i < 240; i++) Offset(r.nextDouble() * 2 - 1, r.nextDouble() * 2 - 1)];
  }

  static const _gold = Color(0xFFFFD66B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    // السماء: من العتمة إلى الأزرق الليلي ثم الزمردي.
    final top = Color.lerp(const Color(0xFF02030A), const Color(0xFF0B2A5B), _ease(cinemaRamp(t, 0, 12)))!;
    final bottom = Color.lerp(const Color(0xFF02030A), const Color(0xFF1F6F6B), _ease(cinemaRamp(t, 5, 12)))!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );

    _drawStars(canvas, size);
    _drawFirstLight(canvas, size);

    if (t > 5) _drawWorldLayer(canvas, size);
    if (t > 22) _drawMap(canvas, size);
    if (t > 15) _drawSisters(canvas, size);
    if (t >= 30 && t <= 38.5) _drawSharedStars(canvas, size);
    if (t >= 10) _drawLamaa(canvas, size);

    // تعتيم الحواف لإحساس سينمائي.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.6, 1],
        ).createShader(Offset.zero & size),
    );
    // البداية والنهاية من/إلى العتمة.
    final black = 1 - _ease(cinemaRamp(t, 0, 0.8));
    if (black > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: black));
    }
  }

  // ---------- المشهد 1: النجوم والنور الأول ----------
  void _drawStars(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final zoom = 1 + 2.2 * _ease(cinemaRamp(t, 0, 5));
    final inWorld = t > 5;
    final paint = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final appear = _ease(cinemaRamp(t, 0.6 + (i % 60) * 0.065, 1.4 + (i % 60) * 0.065));
      if (appear <= 0) continue;
      final p = _stars[i];
      final x = w / 2 + p.dx * zoom * w * 0.5;
      final y = h * 0.45 + p.dy * zoom * h * 0.5;
      if (x < 0 || x > w || y < 0 || y > h) continue;
      if (inWorld && y > h * 0.5) continue;
      final tw = 0.55 + 0.45 * math.sin(t * 2.2 + i);
      final a = appear * tw * (inWorld ? 0.6 : 1.0);
      paint.color = Colors.white.withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 0.8 + (i % 4) * 0.45, paint);
    }
  }

  void _drawFirstLight(Canvas canvas, Size size) {
    final grow = _ease(cinemaRamp(t, 0.4, 5));
    final settle = 1 - 0.8 * _ease(cinemaRamp(t, 5, 9));
    final r = _lerp(3, size.width * 0.45, grow) * (t > 5 ? settle : 1);
    final c = Offset(size.width / 2, size.height * 0.45);
    if (r < 1) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_gold.withValues(alpha: 0.95 * settle), _gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // ---------- المشهد 2: العالم ----------
  void _drawWorldLayer(Canvas canvas, Size size) {
    final reveal = _ease(cinemaRamp(t, 5, 10));
    final drift = 1 + 0.03 * cinemaRamp(t, 10, 38);
    final wide = 1 - 0.06 * _ease(cinemaRamp(t, 43, 45));
    final s = _lerp(1.5, 1, reveal) * drift * wide;
    final dy = (1 - reveal) * size.height * 0.45;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: reveal));
    canvas.translate(center.dx, center.dy + dy);
    canvas.scale(s);
    canvas.translate(-center.dx, -center.dy);
    _drawWorld(canvas, size);
    if (t > 22) _drawMapVeil(canvas, size);
    canvas.restore();
  }

  void _drawWorld(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // جبل بعيد (على اليسار: وجهة فداء) وسلسلة أبعد.
    final far = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.1, h * 0.36)
      ..lineTo(w * 0.2, h * 0.46)
      ..lineTo(w * 0.34, h * 0.4)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.7, h * 0.41)
      ..lineTo(w * 0.86, h * 0.48)
      ..lineTo(w, h * 0.42)
      ..lineTo(w, h * 0.55)
      ..lineTo(0, h * 0.55)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF1B3A66).withValues(alpha: 0.9));
    final peak = Path()
      ..moveTo(w * 0.0, h * 0.54)
      ..lineTo(w * 0.17, h * 0.27)
      ..lineTo(w * 0.34, h * 0.54)
      ..close();
    canvas.drawPath(peak, Paint()..color = const Color(0xFF24507A));
    final snow = Path()
      ..moveTo(w * 0.17, h * 0.27)
      ..lineTo(w * 0.205, h * 0.33)
      ..lineTo(w * 0.17, h * 0.31)
      ..lineTo(w * 0.14, h * 0.335)
      ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // الأرض الزمردية.
    final ground = Rect.fromLTWH(0, h * 0.5, w, h * 0.5);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A8F6D), Color(0xFF0E3B3A)],
        ).createShader(ground),
    );

    // النهر.
    final river = Path()
      ..moveTo(w * 0.62, h * 0.5)
      ..cubicTo(w * 0.7, h * 0.6, w * 0.4, h * 0.72, w * 0.5, h);
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..color = const Color(0xFF5FB7E8).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.25 + 0.2 * math.sin(t * 2)),
    );

    // الغابة (يسار).
    for (var i = 0; i < 16; i++) {
      final x = w * (0.02 + (i % 8) * 0.04) + (i ~/ 8) * 10;
      final y = h * (0.54 + (i ~/ 8) * 0.07 + (i % 3) * 0.015);
      _tree(canvas, Offset(x, y), 16 + (i % 3) * 4.0);
    }

    // القرية (وسط) بقباب وأقواس.
    for (var i = 0; i < 5; i++) {
      final x = w * (0.34 + i * 0.065);
      final y = h * (0.56 + (i % 2) * 0.03);
      _house(canvas, Offset(x, y), 26.0 + (i % 3) * 4);
    }

    // المكتبة الكبيرة (يمين).
    _library(canvas, Offset(w * 0.78, h * 0.55), w * 0.2);

    // الحديقة الملونة (أسفل اليمين).
    for (var i = 0; i < 26; i++) {
      final a = i * 2.4;
      final rr = 8 + (i % 7) * 6.0;
      final c = HSVColor.fromAHSV(1, (i * 47) % 360.0, 0.55, 1).toColor();
      canvas.drawCircle(Offset(w * 0.8 + math.cos(a) * rr * 2.2, h * 0.8 + math.sin(a) * rr * 0.9), 4.5, Paint()..color = c);
    }

    // جسيمات ذهبية تطفو.
    final p = Paint();
    for (var i = 0; i < 40; i++) {
      final x = (i * 97 % 100) / 100 * w + math.sin(t + i) * 8;
      final y = h - (((t * 14 + i * 53) % (h * 0.8)) + h * 0.05);
      p.color = _gold.withValues(alpha: 0.35 + 0.3 * math.sin(t * 2 + i));
      canvas.drawCircle(Offset(x, y), 1.6, p);
    }
  }

  /// العالم يتحوّل إلى خريطة: ظلّ أزرق ناعم، والأماكن تصير نقاطًا مضيئة تعلوها نجوم.
  void _drawMapVeil(Canvas canvas, Size size) {
    final m = _ease(cinemaRamp(t, 22, 30));
    canvas.drawRect(
      (Offset.zero & size).inflate(80),
      Paint()..color = const Color(0xFF0B2A5B).withValues(alpha: 0.5 * m),
    );
    const spots = [
      Offset(0.17, 0.3), // الجبل
      Offset(0.14, 0.6), // الغابة
      Offset(0.5, 0.58), // القرية
      Offset(0.78, 0.46), // المكتبة
      Offset(0.8, 0.8), // الحديقة
      Offset(0.55, 0.75), // النهر
    ];
    for (var i = 0; i < spots.length; i++) {
      final c = Offset(spots[i].dx * size.width, spots[i].dy * size.height);
      final pulse = 0.75 + 0.25 * math.sin(t * 3 + i);
      canvas.drawCircle(c, 16 * m * pulse, Paint()..color = _gold.withValues(alpha: 0.35 * m));
      canvas.drawCircle(c, 6 * m, Paint()..color = const Color(0xFFFFF1B8).withValues(alpha: m));
      _star(canvas, c.translate(0, -22 * m), 5 * m, _gold.withValues(alpha: m * pulse));
    }
  }

  void _tree(Canvas canvas, Offset base, double s) {
    canvas.drawRect(Rect.fromLTWH(base.dx - 2, base.dy - s * 0.4, 4, s * 0.4), Paint()..color = const Color(0xFF5B3A29));
    for (var k = 0; k < 3; k++) {
      final y = base.dy - s * 0.3 - k * s * 0.45;
      final tri = Path()
        ..moveTo(base.dx - s * (0.75 - k * 0.15), y)
        ..lineTo(base.dx, y - s * 0.8)
        ..lineTo(base.dx + s * (0.75 - k * 0.15), y)
        ..close();
      canvas.drawPath(tri, Paint()..color = Color.lerp(const Color(0xFF0F5A44), const Color(0xFF2FAE7B), k / 3)!);
    }
  }

  void _house(Canvas canvas, Offset base, double s) {
    final wall = Rect.fromLTWH(base.dx - s / 2, base.dy - s * 0.8, s, s * 0.8);
    canvas.drawRect(wall, Paint()..color = const Color(0xFFF2DDB8));
    final dome = Path()
      ..moveTo(base.dx - s * 0.5, base.dy - s * 0.8)
      ..quadraticBezierTo(base.dx, base.dy - s * 1.5, base.dx + s * 0.5, base.dy - s * 0.8)
      ..close();
    canvas.drawPath(dome, Paint()..color = const Color(0xFF3FA7A0));
    final glow = 0.7 + 0.3 * math.sin(t * 3 + base.dx);
    final win = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - s * 0.4), width: s * 0.28, height: s * 0.4),
      Radius.circular(s * 0.14),
    );
    canvas.drawRRect(win, Paint()..color = _gold.withValues(alpha: glow));
  }

  void _library(Canvas canvas, Offset base, double wd) {
    final body = Rect.fromLTWH(base.dx - wd / 2, base.dy - wd * 0.4, wd, wd * 0.4);
    canvas.drawRect(body, Paint()..color = const Color(0xFFF7E8C8));
    final dome = Path()
      ..moveTo(base.dx - wd * 0.3, base.dy - wd * 0.4)
      ..quadraticBezierTo(base.dx, base.dy - wd * 1.05, base.dx + wd * 0.3, base.dy - wd * 0.4)
      ..close();
    canvas.drawPath(dome, Paint()..color = const Color(0xFFE0A93B));
    for (var i = 0; i < 4; i++) {
      final x = base.dx - wd * 0.36 + i * wd * 0.24;
      final arch = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, base.dy - wd * 0.3, wd * 0.12, wd * 0.3),
        Radius.circular(wd * 0.06),
      );
      canvas.drawRRect(arch, Paint()..color = _gold.withValues(alpha: 0.65 + 0.3 * math.sin(t * 2 + i)));
    }
  }

  // ---------- لَمعة ----------
  Offset _lamaaPos(double tt, Size s) {
    final w = s.width;
    final h = s.height;
    if (tt < 15) {
      final k = _ease(cinemaRamp(tt, 10, 15));
      return Offset(w * (0.5 + 0.22 * math.sin((tt - 10) * 1.2)), _lerp(h * 0.22, h * 0.42, k));
    }
    if (tt < 22) {
      final a = (tt - 15) * 1.6;
      return Offset(w * 0.5 + math.cos(a) * w * 0.22, h * 0.7 + math.sin(a) * h * 0.04 - h * 0.1);
    }
    if (tt < 38) {
      return Offset(w * 0.5 + math.sin(tt * 0.7) * w * 0.12, h * 0.14 + math.sin(tt * 1.3) * 6);
    }
    // لمعة تتنقل بين المسارين: مسار فداء ثم مسار نور.
    final k = _ease(cinemaRamp(tt, 38, 40));
    return Offset(w * (0.5 + 0.3 * math.sin((tt - 38) * 0.9) * k), _lerp(h * 0.14, h * 0.3, k) + math.sin(tt * 2) * 5);
  }

  void _drawLamaa(Canvas canvas, Size size) {
    final appear = _ease(cinemaRamp(t, 10, 11));
    // أثر من نجوم صغيرة.
    for (var k = 12; k >= 1; k--) {
      final p = _lamaaPos(t - k * 0.12, size);
      final a = (1 - k / 12) * 0.7 * appear;
      _star(canvas, p, 3.2 * (1 - k / 14), _gold.withValues(alpha: a));
    }
    final p = _lamaaPos(t, size);
    final r = (_lerp(26, 13, _ease(cinemaRamp(t, 10, 15)))) * appear * (1 + 0.06 * math.sin(t * 4));
    canvas.drawCircle(
      p,
      r * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [_gold.withValues(alpha: 0.6), _gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: p, radius: r * 2.6)),
    );
    _star(canvas, p, r, const Color(0xFFFFE9A6));
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0) return;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // ---------- المشهد 4: الأختان ----------
  Offset _girlBase(bool fedaa, Size s) => Offset(s.width * (fedaa ? 0.44 : 0.57), s.height * 0.86);

  void _drawSisters(Canvas canvas, Size size) {
    final appear = _ease(cinemaRamp(t, 15, 17));
    final shrink = _lerp(1, 0.5, _ease(cinemaRamp(t, 22, 25)));
    final walk = _ease(cinemaRamp(t, 39, 44));
    for (final fedaa in [true, false]) {
      final base = _girlBase(fedaa, size);
      var pos = base;
      var scale = shrink;
      if (walk > 0) {
        final m = _pathFor(fedaa, size).computeMetrics().first;
        final tan = m.getTangentForOffset(m.length * (fedaa ? 0.5 : 0.45) * walk);
        if (tan != null) pos = Offset.lerp(base, tan.position, walk)!;
        scale = shrink * _lerp(1, 0.7, walk);
      }
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: appear));
      _girl(canvas, pos, size.height * (fedaa ? 0.2 : 0.15) * scale, fedaa);
      canvas.restore();
    }
  }

  void _girl(Canvas canvas, Offset base, double height, bool fedaa) {
    final dress = fedaa ? const Color(0xFFE76F8B) : const Color(0xFFF4B942);
    final hair = fedaa ? const Color(0xFF3B2A25) : const Color(0xFF5A3A28);
    const skin = Color(0xFFF3C9A0);
    final headR = height * 0.17;
    final bodyH = height * 0.5;
    // الفستان.
    final d = Path()
      ..moveTo(base.dx - headR * 0.9, base.dy - height * 0.3)
      ..lineTo(base.dx + headR * 0.9, base.dy - height * 0.3)
      ..lineTo(base.dx + headR * 1.7, base.dy - height * 0.05)
      ..lineTo(base.dx - headR * 1.7, base.dy - height * 0.05)
      ..close();
    canvas.drawPath(d, Paint()..color = dress);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - headR * 0.9, base.dy - height * 0.3 - bodyH * 0.2, headR * 1.8, bodyH * 0.3),
      Paint()..color = dress,
    );
    // الساقان.
    final leg = Paint()..color = skin;
    canvas.drawRect(Rect.fromLTWH(base.dx - headR * 0.7, base.dy - height * 0.05, headR * 0.45, height * 0.05), leg);
    canvas.drawRect(Rect.fromLTWH(base.dx + headR * 0.25, base.dy - height * 0.05, headR * 0.45, height * 0.05), leg);
    // الرأس والشعر والوجه.
    final head = Offset(base.dx, base.dy - height * 0.58 - headR * 0.2);
    canvas.drawCircle(head, headR * 1.12, Paint()..color = hair);
    canvas.drawCircle(head.translate(0, headR * 0.1), headR, Paint()..color = skin);
    final look = fedaa ? -headR * 0.18 : headR * 0.18; // فداء تنظر للجبل ونور للحديقة.
    final eye = Paint()..color = const Color(0xFF2A1B14);
    canvas.drawCircle(head.translate(-headR * 0.35 + look, headR * 0.05), headR * 0.09, eye);
    canvas.drawCircle(head.translate(headR * 0.35 + look, headR * 0.05), headR * 0.09, eye);
    final smile = Path()
      ..moveTo(head.dx - headR * 0.3 + look, head.dy + headR * 0.42)
      ..quadraticBezierTo(head.dx + look, head.dy + headR * 0.72, head.dx + headR * 0.3 + look, head.dy + headR * 0.42);
    canvas.drawPath(
      smile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, headR * 0.07)
        ..color = const Color(0xFF9A4B3A),
    );
    // خدّان ورديان.
    final cheek = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.45);
    canvas.drawCircle(head.translate(-headR * 0.6 + look, headR * 0.3), headR * 0.14, cheek);
    canvas.drawCircle(head.translate(headR * 0.6 + look, headR * 0.3), headR * 0.14, cheek);
  }

  // ---------- المشهد 5: الخريطة ورحلتان مختلفتان ----------
  Path _pathFor(bool fedaa, Size s) {
    final w = s.width;
    final h = s.height;
    if (fedaa) {
      return Path()
        ..moveTo(w * 0.44, h * 0.8)
        ..cubicTo(w * 0.2, h * 0.72, w * 0.55, h * 0.58, w * 0.3, h * 0.46)
        ..cubicTo(w * 0.12, h * 0.38, w * 0.3, h * 0.3, w * 0.18, h * 0.2);
    }
    return Path()
      ..moveTo(w * 0.57, h * 0.8)
      ..cubicTo(w * 0.72, h * 0.72, w * 0.8, h * 0.6, w * 0.78, h * 0.5)
      ..cubicTo(w * 0.76, h * 0.44, w * 0.84, h * 0.38, w * 0.86, h * 0.34);
  }

  static const _fedaaIcons = ['🌲', '🔢', '🔬', '📚', '❤️'];
  static const _nourIcons = ['🌸', '🔷', '🔊', '🔍'];

  void _drawMap(Canvas canvas, Size size) {
    final alpha = _ease(cinemaRamp(t, 22, 24));
    final pulse = 0.7 + 0.3 * math.sin(t * 3);
    final endGlow = _ease(cinemaRamp(t, 38, 41));
    for (final fedaa in [true, false]) {
      final path = _pathFor(fedaa, size);
      final m = path.computeMetrics().first;
      final prog = _ease(cinemaRamp(t, fedaa ? 23 : 24.5, fedaa ? 28.5 : 28));
      final color = fedaa ? _gold : const Color(0xFFFF9EC4);
      final drawn = m.extractPath(0, m.length * prog);
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.28 * alpha * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fedaa ? 4 : 6
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.95 * alpha),
      );
      final icons = fedaa ? _fedaaIcons : _nourIcons;
      for (var i = 0; i < icons.length; i++) {
        final f = (i + 1) / icons.length;
        if (prog < f - 0.02) continue;
        final tan = m.getTangentForOffset(m.length * f);
        if (tan == null) continue;
        final pop = _ease(cinemaRamp(prog, f - 0.02, f + 0.06));
        final r = (fedaa ? 17.0 : 22.0) * pop;
        canvas.drawCircle(tan.position, r + 4, Paint()..color = color.withValues(alpha: 0.35 * pulse));
        canvas.drawCircle(tan.position, r, Paint()..color = Colors.white.withValues(alpha: 0.92));
        _emoji(canvas, icons[i], tan.position, r * 1.15);
      }
      // المشهد 7: بوابة مضيئة في نهاية كل مسار.
      if (endGlow > 0) {
        final end = m.getTangentForOffset(m.length)!.position;
        final rr = (fedaa ? 34.0 : 28.0) * endGlow * (0.9 + 0.1 * math.sin(t * 5));
        canvas.drawCircle(
          end,
          rr * 1.8,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withValues(alpha: 0.8 * endGlow), color.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: end, radius: rr * 1.8)),
        );
      }
    }
    // ضباب فوق المناطق التي لم تُكتشف بعد.
    final mist = Paint()..color = Colors.white.withValues(alpha: 0.12 * alpha);
    for (var i = 0; i < 6; i++) {
      final dx = size.width * (0.08 + i * 0.17) + math.sin(t * 0.5 + i) * 10;
      canvas.drawCircle(Offset(dx, size.height * (0.12 + (i % 2) * 0.05)), 42, mist);
    }
  }

  void _emoji(Canvas canvas, String e, Offset c, double size) {
    final tp = TextPainter(
      text: TextSpan(text: e, style: TextStyle(fontSize: size * 1.1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------- المشهد 6: النجمة المشتركة ----------
  void _drawSharedStars(Canvas canvas, Size size) {
    final f = _pathFor(true, size).computeMetrics().first;
    final n = _pathFor(false, size).computeMetrics().first;
    final fp = f.getTangentForOffset(f.length * 0.5)!.position;
    final np = n.getTangentForOffset(n.length * 0.5)!.position;
    void flight(Offset a, Offset b, double k) {
      Offset at(double x) =>
          Offset.lerp(a, b, x)! - Offset(0, math.sin(math.pi * x) * size.height * 0.16);
      for (var i = 10; i >= 1; i--) {
        final x = (k - i * 0.025).clamp(0.0, 1.0);
        _star(canvas, at(x), 3.5 * (1 - i / 11), _gold.withValues(alpha: (1 - i / 10) * 0.7));
      }
      final p = at(k);
      canvas.drawCircle(
        p,
        24,
        Paint()
          ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.7), _gold.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: p, radius: 24)),
      );
      _star(canvas, p, 11, const Color(0xFFFFF1B8));
    }

    final k1 = cinemaRamp(t, 31, 34.5);
    if (t >= 31 && t < 35) flight(fp, np, _ease(k1));
    final k2 = cinemaRamp(t, 35, 38);
    if (t >= 35) flight(np, fp, _ease(k2));
  }

  @override
  bool shouldRepaint(CinemaPainter old) => old.t != t;
}
