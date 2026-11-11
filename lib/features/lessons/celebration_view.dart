import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
  });

  final String childName;
  final LessonCompletion completion;
  final VoidCallback onContinue;

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
      duration: const Duration(milliseconds: 2400),
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
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0, 0.5, curve: Curves.elasticOut),
                    ),
                    child: Text(
                      reward.stars >= 2 ? '🌟' : '⭐',
                      style: const TextStyle(fontSize: 120),
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
                  if (reward.isFirstCompletion && reward.perfect) ...[
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
                  SizedBox(
                    width: double.infinity,
                    height: 66,
                    child: ElevatedButton(
                      onPressed: widget.onContinue,
                      child: const Text('متابعة'),
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
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

/// كونفيتي بسيط: 28 دائرة صغيرة تتساقط بحركة خفيفة (بدون صور أو حزم).
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const List<Color> _colors = [
    AppColors.sun,
    AppColors.rose,
    AppColors.teal,
    AppColors.leaf,
    Color(0xFF6C7BD9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 28; i++) {
      final baseX = size.width * ((i * 0.618034) % 1.0);
      final speed = 0.7 + ((i * 7) % 5) / 10;
      final y = t * speed * size.height * 1.3 - 30 - (i % 6) * 28;
      if (y < -10 || y > size.height) continue;
      final x = baseX + math.sin(t * 6 + i) * 14;
      paint.color = _colors[i % _colors.length];
      canvas.drawCircle(Offset(x, y), 4.0 + (i % 3) * 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
