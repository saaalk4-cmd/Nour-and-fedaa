import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/brand_mark.dart';
import 'onboarding_scaffold.dart';

class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      canGoBack: false,
      title: 'كل شيء جاهز',
      subtitle: 'يمكنك تغيير المسار أو المستوى في أي وقت من لوحة ولي الأمر',
      child: Column(
        children: [
          const Spacer(),
          const BrandMark(width: 160),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'ادخل إلى براق',
              onPressed: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}
