import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import 'onboarding_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const BrandMark(width: 190),
              const SizedBox(height: 36),
              const Text(
                'أهلًا بك في براق',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'رحلة تعلّم من سنتين إلى ١٤ سنة',
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.8),
                  fontSize: 19,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: GoldButton(
                  label: 'ابدأ',
                  onPressed: () => context.go('/onboarding/account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
