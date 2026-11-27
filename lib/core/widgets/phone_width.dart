import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// على الأجهزة العريضة (تابلت) تُعرض الواجهة بعرض هاتف في المنتصف
/// بدل تمدّد البلاطات والأزرار على العرض كله.
class PhoneWidth extends StatelessWidget {
  const PhoneWidth({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth + 40) return child;
    return ColoredBox(
      color: AppColors.navy,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
