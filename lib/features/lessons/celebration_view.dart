import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/big_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/models/lesson_completion.dart';
import '../../domain/gamification/level_system.dart';

/// شاشة احتفال قصيرة بعد إكمال الدرس: نجوم، XP، تقدم المستوى، وسلسلة الأيام.
/// خفيفة الأداء: متحكم حركة واحد + رسم بسيط بدون حزم خارجية.
class CelebrationView extends StatefulWidget {
  const CelebrationView({
    super.key,
    required this.childName,
    required this.completion,
    required this.onContinue,
    this.little = false,
    this.learned,
  });

  final String childName;

  /// للصغيرات (3-4 سنوات): شخصية أكبر ونص أقل.
  final bool little;
  final LessonCompletion completion;
  final VoidCallback onContinue;

  /// «ماذا تعلمتِ؟» (اختيارية).
  final String? learned;

  @override
  State<CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<CelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _message {
    final name = widget.childName;
    final c = widget.completion;
    if (!c.reward.isFirstCompletion) return 'جميل أنكِ راجعتِ الدرس يا $name!';
    final options = ['أحسنتِ يا $name!', 'رائع يا $name!', 'أنتِ تتقدمين يا $name!'];
    return options[c.totalXp % options.length];
  }

  String? get _streakMessage {
    final s = widget.completion.streak;
    if (s.welcomeBack) return 'أهلًا بعودتك يا بطلة ❤️\nنكمل رحلتنا من هنا.';
    if (s.extended && s.current >= 2) return '🔥 ${s.current} أيام متتالية';
    if (s.extended) return '🔥 بدأتِ سلسلة جديدة';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.completion;
    final reward = c.reward;
    final streakMessage = _streakMessage;
    final level = LevelSystem.info(c.newLevel);

    final oldXp = c.totalXp - c.gainedXp;
    final oldFraction = (oldXp % LevelSystem.xpPerLevel) / LevelSystem.xpPerLevel;
    final newFraction =
        (c.totalXp % LevelSystem.xpPerLevel) / LevelSystem.xpPerLevel;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_controller.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                  SizedBox(
                    width: 280,
                    height: widget.little ? 250 : 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => CustomPaint(
                            size: const Size(280, 280),
                            painter: _RaysPainter(_controller.value),
                          ),
                        ),
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _controller,
                            curve: const Interval(0, 0.35, curve: Curves.elasticOut),
                          ),
                          child: Mascot(
                            size: widget.little ? 200 : 150,
                            mood: MascotMood.cheer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _RewardChip(text: '⚡ +${reward.xp} XP', color: AppColors.sun),
                      if (reward.stars > 0)
                        _RewardChip(
                          text: '⭐ +${reward.stars} ${reward.stars == 1 ? 'نجمة' : 'نجوم'}',
                          color: AppColors.rose,
                        ),
                      if (c.dailyBonusEarned)
                        _RewardChip(
                          text: '🎯 مهام اليوم +${c.bonusXp} XP',
                          color: AppColors.leaf,
                        ),
                    ],
                  ),
                  if (c.dailyBonusEarned) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '🎉 أكملتِ كل مهام اليوم!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                  if (widget.learned != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '💡 ماذا تعلمتِ؟\n${widget.learned}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: c.leveledUp ? 0 : oldFraction,
                      end: newFraction,
                    ),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 16,
                        backgroundColor: Colors.white,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${level.icon} ${level.name} — المستوى ${c.newLevel}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  if (c.leveledUp) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '🎉 وصلتِ إلى مستوى جديد!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                  if (streakMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      streakMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (!widget.little && reward.isFirstCompletion && reward.perfect) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '✨ أجبتِ عن كل الأسئلة من أول مرة!',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                  for (final b in c.newBadges) ...[
                    const SizedBox(height: 12),
                    Text(
                      '🏅 شارة جديدة: ${b.emoji} ${b.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BigButton(label: 'متابعة', onPressed: widget.onContinue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v.clamp(0.0, 1.4), child: child),
      child: _chip(),
    );
  }

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// أشعة ذهبية تدور ببطء خلف لَمعة.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x99FFE49A), Color(0x00FFE49A)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * math.pi * 0.8);
    for (var i = 0; i < 12; i++) {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(i * math.pi / 6 - 0.12) * r, math.sin(i * math.pi / 6 - 0.12) * r)
        ..lineTo(math.cos(i * math.pi / 6 + 0.12) * r, math.sin(i * math.pi / 6 + 0.12) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t;
}

/// كونفيتي ملوّن: دوائر ومستطيلات تدور ونجوم صغيرة، تتساقط على كامل الشاشة (بلا صور ولا حزم).
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const List<Color> _colors = [
    AppColors.sun,
    AppColors.rose,
    AppColors.teal,
    AppColors.leaf,
    Color(0xFF6C7BD9),
    Color(0xFFFF9F5A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 56; i++) {
      final baseX = size.width * ((i * 0.618034) % 1.0);
      final speed = 0.55 + ((i * 7) % 6) / 10;
      final y = (t * speed * size.height * 1.5) - 40 - (i % 9) * 36;
      if (y < -12 || y > size.height + 12) continue;
      final x = baseX + math.sin(t * 7 + i) * 18;
      paint.color = _colors[i % _colors.length];
      switch (i % 3) {
        case 0:
          canvas.drawCircle(Offset(x, y), 4.0 + (i % 3) * 2, paint);
        case 1:
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t * 9 + i)
            ..drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(2)),
              paint,
            )
            ..restore();
        default:
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t * 5 + i)
            ..drawPath(_star(7), paint)
            ..restore();
      }
    }
  }

  Path _star(double r) {
    final p = Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + k * math.pi / 5;
      final pt = Offset(math.cos(a) * rad, math.sin(a) * rad);
      if (k == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
