import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';

/// هيكل مشترك لشاشات التسجيل: رأس بالعلامة، عنوان، محتوى، وزر سفلي.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.step,
    this.subtitle,
    this.canGoBack = true,
    this.dark = false,
  });

  final String title;
  final String? subtitle;

  /// مثال: «الخطوة ١ من ٣».
  final String? step;
  final Widget child;
  final bool canGoBack;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.cream : AppColors.navy;
    return Scaffold(
      backgroundColor: dark ? AppColors.navy : AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(width: 72),
                  const Spacer(),
                  if (step != null)
                    Text(step!,
                        style: TextStyle(
                            color: fg.withValues(alpha: 0.75), fontSize: 16)),
                  if (canGoBack && Navigator.of(context).canPop())
                    IconButton(
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_forward, color: fg),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 17),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر رئيسي ذهبي كبير.
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}
