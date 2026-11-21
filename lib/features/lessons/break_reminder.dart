import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/voice_service.dart';
import '../../core/design/big_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';

/// تنبيه استراحة لطيف: الطفلة تذاكر وحدها، فبعد مدة من اللعب نقترح عليها
/// أن تشرب ماء وتتحرك قليلًا. لا عقاب ولا منع: تستطيع المتابعة.
class BreakReminder {
  BreakReminder._();

  /// مدة اللعب المتواصل قبل الاقتراح.
  static Duration interval = const Duration(minutes: 15);

  static DateTime _anchor = DateTime.now();

  /// يُستدعى بعد إنهاء الدرس. يعرض الاقتراح إن مضت [interval] منذ آخر استراحة.
  static bool due(DateTime now, {DateTime? anchor}) =>
      now.difference(anchor ?? _anchor) >= interval;

  static void reset([DateTime? now]) => _anchor = now ?? DateTime.now();

  static Future<void> maybeShow(BuildContext context, VoiceService voice) async {
    if (!due(DateTime.now())) return;
    reset();
    voice.speak('وقت استراحة! اشربي ماء وتحركي قليلًا ثم نكمل');
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
              const Mascot(size: 110, mood: MascotMood.cheer),
              const SizedBox(height: 8),
              Text('وقت استراحة 🌸', style: AppText.display(30)),
              const SizedBox(height: 8),
              const Text(
                'اشربي ماء 💧 وتحركي قليلًا 🤸\nثم نكمل معًا',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.5),
              ),
              const SizedBox(height: 18),
              BigButton(label: 'تمام 👍', onPressed: () => ctx.pop()),
            ],
          ),
        ),
      ),
    );
  }
}
