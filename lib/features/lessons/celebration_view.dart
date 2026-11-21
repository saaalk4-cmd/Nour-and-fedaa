import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/design/art.dart';
import '../../core/design/joy.dart';
import '../../core/design/kit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/models/lesson_completion.dart';
import '../../data/providers.dart';

/// شاشة احتفال قصيرة بعد إكمال الدرس: البنت تحتفل مع لَمعة، نجوم الدرس، والشارات.
/// لا XP ولا مستويات ولا سلاسل أيام أمام الطفلة (مكانها لوحة الأهل).
/// خفيفة الأداء: متحكم حركة واحد + رسم بسيط بدون حزم خارجية.
class CelebrationView extends ConsumerStatefulWidget {
  const CelebrationView({
    super.key,
    required this.childName,
    required this.completion,
    required this.onContinue,
    this.little = false,
    this.learned,
    this.calm = false,
  });

  /// قرآن/أذكار/صلاة: احتفال هادئ (نجمة فقط) بلا كونفيتي ولا موسيقى.
  final bool calm;

  final String childName;

  /// للصغيرات (3-4 سنوات): شخصية أكبر ونص أقل.
  final bool little;
  final LessonCompletion completion;
  final VoidCallback onContinue;

  /// «ماذا تعلمتِ؟» (اختيارية).
  final String? learned;

  @override
  ConsumerState<CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends ConsumerState<CelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final VoiceService _voice = ref.read(voiceServiceProvider);
  bool _joy = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
    if (!widget.calm) ref.read(soundServiceProvider).play(SoundEffect.joy);
    Future<void>.delayed(JoyBurst.duration, () {
      if (mounted) setState(() => _joy = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  /// كل ما على الشاشة يُقال: التهنئة، ثم «ماذا تعلمتِ»، ثم الشارات الجديدة.
  Future<void> _speak() async {
    await _voice.sayAndWait(_message);
    final learned = widget.learned;
    if (learned != null && mounted) await _voice.sayAndWait('ماذا تعلمتِ؟ $learned', max: const Duration(seconds: 12));
    for (final b in widget.completion.newBadges) {
      if (!mounted) return;
      await _voice.sayAndWait('شارة جديدة: ${b.title}');
    }
  }

  @override
  void dispose() {
    _voice.stop();
    _controller.dispose();
    super.dispose();
  }

  String get _message {
    final name = widget.childName;
    final c = widget.completion;
    if (!c.reward.isFirstCompletion) return 'جميل أنكِ راجعتِ الدرس يا $name!';
    final options = [
      'أحسنتِ يا $name!',
      'ما شاء الله عليكِ يا $name!',
      'رائعة يا $name!',
      'أنتِ تتقدمين يا $name!',
    ];
    return options[c.totalXp % options.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.completion;
    final reward = c.reward;

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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // البنت نفسها وهي تحتفل، ولَمعة جنبها.
                              ArtImage(widget.little ? Art.nourCheer : Art.fedaaCheer,
                                  height: widget.little ? 230 : 190),
                              Mascot(size: widget.little ? 110 : 90, mood: MascotMood.cheer),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ParchmentCard(
                    child: Column(
                      children: [
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: AppText.display(widget.little ? 34 : 30, color: Wood.text),
                        ),
                        // نجوم الدرس فقط (بلا أرقام ولا نجوم فارغة).
                        if (reward.stars > 0) ...[
                          const SizedBox(height: 8),
                          StarRow(filled: reward.stars, total: reward.stars, size: 52),
                        ],
                        if (widget.learned != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '💡 ${widget.learned}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // شارة جديدة: ميدالية + اسمها.
                  for (final b in c.newBadges) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ArtImage(Art.medal, height: 70),
                        const SizedBox(width: 8),
                        Flexible(
                          child: OutlineText('${b.emoji} ${b.title}', size: 24, stroke: Wood.edge),
                        ),
                      ],
                    ),
                  ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SunButton(label: 'متابعة', onTap: widget.onContinue),
                ],
              ),
            ),
          ),
          if (_joy)
            Positioned.fill(
              child: JoyBurst(
                level: JoyLevel.big,
                text: widget.calm ? null : 'ما شاء الله!',
                calm: widget.calm,
                reduceMotion: ref.watch(reduceMotionProvider).valueOrNull ?? false,
              ),
            ),
        ],
      ),
    );
  }
}

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
