import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'art.dart';
import 'pop_tap.dart';

/// عناصر «عالمنا السحري»: لافتات خشب، أزرار دائرية لامعة، ورقة تشجيع، شريط،
/// وكارت المهمة. كلها مرسومة بالكود (واضحة على أي شاشة) والكلام نص حقيقي.
class Wood {
  static const Color light = Color(0xFFF9CF8A);
  static const Color mid = Color(0xFFE9A657);
  static const Color dark = Color(0xFFB06A2B);
  static const Color edge = Color(0xFF7A4316);
  static const Color text = Color(0xFF4A2508);
  static const Color cream = Color(0xFFFFF4DA);
  static const Color creamDark = Color(0xFFF6DDA6);
  static const Color leaf = Color(0xFF5DBB4A);
}

/// نص بإطار (أبيض بحدّ غامق، أو العكس): يبقى واضحًا فوق أي صورة.
class OutlineText extends StatelessWidget {
  const OutlineText(
    this.text, {
    super.key,
    required this.size,
    this.fill = Colors.white,
    this.stroke = Wood.edge,
    this.strokeWidth,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
  });

  final String text;
  final double size;
  final Color fill;
  final Color stroke;
  final double? strokeWidth;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final w = strokeWidth ?? (size / 7).clamp(2.5, 8.0);
    final base = AppText.display(size);
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: fill),
        ),
      ],
    );
  }
}

/// دائرة بيضاء صغيرة فيها سهم (نهاية كل لافتة وكارت).
class ChevronBubble extends StatelessWidget {
  const ChevronBubble({super.key, this.color = const Color(0xFFE07B1F), this.size = 44});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      // في واجهة عربية «التالي» على اليسار.
      child: Icon(Icons.chevron_left_rounded, color: color, size: size * 0.8),
    );
  }
}

/// لافتة خشب: أيقونة في دائرة + عنوان (+ سطر صغير) + سهم.
class WoodSign extends StatelessWidget {
  const WoodSign({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.height = 84,
    this.titleSize = 26,
  });

  final String title;
  final String? subtitle;

  /// غالبًا إيموجي أو صورة صغيرة.
  final Widget? icon;
  final VoidCallback onTap;
  final double height;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: PopTap(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Wood.light, Wood.mid, Wood.dark],
              stops: [0, 0.55, 1],
            ),
            border: Border.all(color: Wood.edge, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 5))],
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: height - 22,
                  height: height - 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Wood.cream,
                    border: Border.all(color: Wood.edge, width: 2),
                  ),
                  child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: icon)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(titleSize, color: Wood.text),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wood.text),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ChevronBubble(size: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر دائري لامع بلا كلمات. [label] للقارئ الصوتي فقط.
class GlossyButton extends StatelessWidget {
  const GlossyButton({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    this.icon,
    this.child,
    this.size = 64,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size < 56 ? 56.0 : size;
    final light = Color.lerp(color, Colors.white, 0.45)!;
    final dark = Color.lerp(color, Colors.black, 0.25)!;
    return Semantics(
      button: true,
      label: label,
      child: PopTap(
        onTap: onTap,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: const Alignment(0, -0.4), radius: 0.9, colors: [light, color, dark]),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: dark.withValues(alpha: 0.55), blurRadius: 8, offset: const Offset(0, 5))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // لمعة بيضاوية أعلى الزر.
              Positioned(
                top: s * 0.08,
                child: Container(
                  width: s * 0.52,
                  height: s * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(s),
                  ),
                ),
              ),
              child ??
                  Icon(
                    icon,
                    color: Colors.white,
                    size: s * 0.52,
                    shadows: [Shadow(color: dark, blurRadius: 2, offset: const Offset(0, 2))],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة كريمية بحدّ خشبي (رسائل التشجيع).
class ParchmentCard extends StatelessWidget {
  const ParchmentCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Wood.cream, Wood.creamDark],
        ),
        border: Border.all(color: Wood.dark, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Wood.text, fontWeight: FontWeight.w800),
        child: child,
      ),
    );
  }
}

/// شريط وردي بطرفين مطويّين («مهمة جديدة!»).
class RibbonBanner extends StatelessWidget {
  const RibbonBanner({super.key, required this.text, this.color = const Color(0xFFE8457E), this.size = 28});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RibbonPainter(color),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 1.6, vertical: size * 0.35),
        child: OutlineText(text, size: size, stroke: Color.lerp(color, Colors.black, 0.45)!, maxLines: 1),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Color.lerp(color, Colors.black, 0.3)!;
    final tail = size.height * 0.55;
    final drop = size.height * 0.22;
    // الطرفان الخلفيان.
    final back = Paint()..color = dark;
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : size.width;
      final dir = left ? 1.0 : -1.0;
      final p = Path()
        ..moveTo(x0 + dir * tail, drop)
        ..lineTo(x0 - dir * tail * 0.15, drop)
        ..lineTo(x0 + dir * tail * 0.35, size.height / 2 + drop)
        ..lineTo(x0 - dir * tail * 0.15, size.height + drop)
        ..lineTo(x0 + dir * tail, size.height + drop)
        ..close();
      canvas.drawPath(p, back);
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(tail * 0.6, 0, size.width - tail * 1.2, size.height),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ).createShader(body.outerRect),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}

/// زر أصفر عريض («ابدأ الآن»).
class SunButton extends StatelessWidget {
  const SunButton({super.key, required this.label, required this.onTap, this.height = 64});

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PopTap(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE46B), Color(0xFFFFC21F), Color(0xFFF29A00)],
            ),
            border: Border.all(color: const Color(0xFFC46A00), width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66C46A00), blurRadius: 8, offset: Offset(0, 5))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(height * 0.46, color: Wood.text),
                ),
              ),
              const SizedBox(width: 10),
              ChevronBubble(color: const Color(0xFFE07B1F), size: height * 0.62),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف نجوم (ممتلئة لما أُنجز، فارغة للباقي). لا أرقام.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.filled, required this.total, this.size = 36});

  final int filled;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < total; i++) ArtImage(i < filled ? Art.starOn : Art.starOff, width: size, height: size),
      ],
    );
  }
}

/// كارت الطفلة («فداء — 5 سنوات»): صورة دائرية + الاسم + سهم.
class KidPill extends StatelessWidget {
  const KidPill({
    super.key,
    required this.name,
    required this.subtitle,
    required this.art,
    required this.color,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String art;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.55)!;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    return Semantics(
      button: true,
      label: name,
      child: PopTap(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, color]),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [BoxShadow(color: dark.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 7))],
          ),
          child: Row(
            children: [
              Container(
                width: 98,
                height: 98,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ArtImage(art, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: OutlineText(name, size: 44, stroke: dark, maxLines: 1),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark),
                    ),
                  ],
                ),
              ),
              ChevronBubble(color: dark, size: 46),
            ],
          ),
        ),
      ),
    );
  }
}

/// لافتة الشعار: «نور وفداء» بخط كبير ملوّن على لوح خشب وتحتها سطر صغير.
class LogoSign extends StatelessWidget {
  const LogoSign({super.key, required this.title, required this.subtitle, this.titleSize = 52});

  final String title;
  final String subtitle;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Wood.light, Wood.mid],
        ),
        border: Border.all(color: Wood.edge, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: OutlineText(title, size: titleSize, fill: const Color(0xFFFF5F9E), stroke: Colors.white, maxLines: 1),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Wood.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Wood.dark, width: 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                maxLines: 1,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Wood.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
