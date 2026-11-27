import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بديل لطيف للشاشة الحمراء إن تعطّل جزء من الواجهة في نسخة الإنتاج.
class FriendlyError extends StatelessWidget {
  const FriendlyError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: AppColors.cream,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌙', style: TextStyle(fontSize: 56)),
                SizedBox(height: 12),
                Text(
                  'حدث خطأ بسيط، ارجع للخلف وحاول مرة أخرى',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.navy, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يُستدعى في main: الشاشة اللطيفة في الإنتاج، وتفاصيل الخطأ أثناء التطوير.
void installFriendlyErrors() {
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const FriendlyError();
  }
}
