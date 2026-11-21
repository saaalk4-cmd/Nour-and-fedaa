import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/voice_service.dart';
import '../../core/design/big_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../domain/gamification/milestones.dart';

/// نافذة احتفال بمكافأة أسبوع/4 أسابيع/التخرج. تظهر بعد شاشة إكمال الدرس.
class MilestoneDialog {
  MilestoneDialog._();

  static Future<void> show(
    BuildContext context,
    VoiceService voice,
    List<Milestone> items,
    String childName,
  ) async {
    for (final m in items) {
      if (!context.mounted) return;
      voice.speak(m.graduation
          ? 'مبروك يا $childName! تخرّجتِ من رحلتك الأولى'
          : 'أحسنتِ يا $childName! ${m.title}');
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(size: 100, mood: MascotMood.cheer),
                Text(m.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 6),
                Text(m.title, textAlign: TextAlign.center, style: AppText.display(28)),
                const SizedBox(height: 8),
                // نجوم فقط، بلا XP أمام الطفلة.
                Text(
                  '⭐' * m.stars.clamp(1, 5),
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 16),
                BigButton(label: 'شكرًا 🎉', onPressed: () => ctx.pop()),
              ],
            ),
          ),
        ),
      );
    }
  }
}
