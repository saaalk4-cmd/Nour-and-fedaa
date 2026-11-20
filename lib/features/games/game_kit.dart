import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/ayah_player.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../data/content/lesson.dart' show Recitation;

/// ما تحتاجه أي لعبة: الصوت والتشجيع والعمر. محركات الألعاب لا تعرف قاعدة البيانات.
class GameKit {
  GameKit({
    required this.voice,
    required this.ayah,
    required this.sound,
    required this.childName,
    required this.little,
    required this.respectful,
    required this.seed,
  }) : rng = math.Random(seed);

  final VoiceService voice;
  final AyahPlayer ayah;
  final SoundService sound;
  final String childName;

  /// نور (3 سنوات): بطاقات أكبر، خيارات أقل، تلميح أسرع.
  final bool little;

  /// قرآن/أذكار: لا مؤثرات صوتية فوق التلاوة.
  final bool respectful;
  final int seed;
  final math.Random rng;

  static const praises = ['أحسنتِ يا {n}!', 'رائعة يا {n}!', 'ممتاز!', 'نجمة اليوم'];
  static const tryAgain = ['قريبة جدًا! جربي مرة ثانية', 'حاولي مرة أخرى', 'ممتاز، جربي مرة أخرى'];

  int _p = 0;
  int _t = 0;

  String praise() => praises[(_p++ + seed) % praises.length].replaceAll('{n}', childName);
  String encourage() => tryAgain[_t++ % tryAgain.length];

  Future<void> say(String text) => voice.speak(text);
  Future<void> sayWait(String text) => voice.sayAndWait(text, max: const Duration(seconds: 8));

  /// تلاوة الشيخ (تنتظر حتى تنتهي). لا شيء آخر يُشغَّل فوقها.
  Future<void> recite(Recitation r) async {
    await voice.stop();
    if (!await voice.isEnabled()) return; // زر الكتم يكتم التلاوة أيضًا
    await ayah.playRange(r.surah, r.ayah, r.toAyah);
  }

  Future<void> stop() async {
    await voice.stop();
    await ayah.stop();
  }

  void good() {
    HapticFeedback.lightImpact();
    if (!respectful) sound.play(SoundEffect.correct);
  }

  void soft() {
    HapticFeedback.selectionClick();
    if (!respectful) sound.play(SoundEffect.tap);
  }

  List<T> shuffled<T>(Iterable<T> xs) => xs.toList()..shuffle(rng);
}

/// تقرير الجولة للعبة: عدد الزلّات (0 = من أول مرة). النجمة لمن زلّ مرة واحدة على الأكثر.
typedef RoundDone = void Function(int slips);

enum PickState { neutral, right, tried, hint, dim }

final _tashkeel = RegExp('[\u064B-\u0652\u0670]');

/// بطاقة اختيار كبيرة: رمز (+ كلمة). تهتز برفق عند المحاولة، وتلمع عند التلميح.
class PickCard extends StatefulWidget {
  const PickCard({
    super.key,
    required this.emoji,
    required this.onTap,
    this.label,
    this.state = PickState.neutral,
    this.big = false,
    this.color,
  });

  final String emoji;
  final String? label;
  final VoidCallback? onTap;
  final PickState state;
  final bool big;
  final Color? color;

  @override
  State<PickCard> createState() => _PickCardState();
}

class _PickCardState extends State<PickCard> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();

  @override
  void didUpdateWidget(PickCard old) {
    super.didUpdateWidget(old);
    if (widget.state == PickState.tried && old.state != PickState.tried) _shake.forward(from: 0);
    if (widget.state == PickState.hint) {
      _glow.repeat(reverse: true);
    } else {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _glow.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final bg = switch (s) {
      PickState.right => const Color(0xFFCDF3C2),
      PickState.tried => const Color(0xFFFFE6C2),
      _ => widget.color ?? Wood.cream,
    };
    final border = switch (s) {
      PickState.right => const Color(0xFF3F8F2F),
      PickState.hint => const Color(0xFF2A9D8F),
      _ => Wood.dark,
    };
    final label = widget.label;
    final card = Container(
      constraints: BoxConstraints(minHeight: widget.big ? 150 : 104),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border, width: 4),
        boxShadow: const [BoxShadow(color: Wood.edge, offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.emoji.isNotEmpty)
            FittedBox(child: Text(widget.emoji, style: TextStyle(fontSize: widget.big ? 76 : 50, height: 1.1))),
          if (label != null && label.isNotEmpty) ...[
            const SizedBox(height: 4),
            // نص مشكَّل (آية): خط النص العادي بحجم مريح وبلا قص؛ الكلمات القصيرة بخط العناوين.
            if (_tashkeel.allMatches(label).length >= 3)
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, height: 1.7, fontWeight: FontWeight.w700, color: Wood.text),
              )
            else
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(widget.big ? 30 : 24, color: Wood.text),
              ),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      label: label ?? widget.emoji,
      child: Opacity(
        opacity: s == PickState.dim ? 0.45 : 1,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shake, _glow, _in]),
          builder: (context, child) {
            final dx = math.sin(_shake.value * math.pi * 4) * 8 * (1 - _shake.value);
            final scale = (0.7 + 0.3 * Curves.easeOutBack.transform(_in.value)) * (1 + 0.06 * _glow.value);
            return Transform.translate(offset: Offset(dx, 0), child: Transform.scale(scale: scale, child: child));
          },
          child: PopTap(onTap: s == PickState.right || s == PickState.dim ? null : widget.onTap, child: card),
        ),
      ),
    );
  }
}

/// لَمعة + فقاعة التعليمات (نص قليل، والصوت هو الأساس).
class GamePrompt extends StatelessWidget {
  const GamePrompt({super.key, required this.text, this.mood = Art.lamaaThink, this.trailing});

  final String text;
  final String mood;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ArtImage(mood, width: 78, height: 78),
        const SizedBox(width: 6),
        Expanded(
          child: ParchmentCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(text, style: const TextStyle(fontSize: 20, height: 1.3)),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// زر «اسمعي مرة أخرى» الكبير (حلقة تتحرك أثناء التشغيل).
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.onTap, this.size = 64});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GlossyButton(color: const Color(0xFF2A9D8F), label: 'اسمعي مرة أخرى', icon: Icons.volume_up_rounded, size: size, onTap: onTap);
  }
}

/// نجوم تطير من نقطة (احتفال خفيف وقصير).
class StarBurst extends StatefulWidget {
  const StarBurst({super.key, required this.trigger});

  /// كل تغيير في القيمة يطلق دفعة جديدة.
  final int trigger;

  @override
  State<StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<StarBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(StarBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final t = Curves.easeOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 8; i++)
                Transform.translate(
                  offset: Offset(math.cos(i * math.pi / 4) * 120 * t, math.sin(i * math.pi / 4) * 120 * t - 40 * t),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.rotate(angle: t * 1.2, child: const ArtImage(Art.starOn, width: 38, height: 38)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// شبكة بطاقات بعدد أعمدة مناسب (2 أو 3) بلا تمدد فوق الفراغ.
class PickGrid extends StatelessWidget {
  const PickGrid({super.key, required this.children, this.columns = 2, this.spacing = 12});

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final row = children.sublist(i, math.min(i + columns, children.length));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var k = 0; k < columns; k++) ...[
            if (k > 0) SizedBox(width: spacing),
            Expanded(child: k < row.length ? row[k] : const SizedBox.shrink()),
          ],
        ],
      ));
      if (i + columns < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
