import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_scaffold.dart';

/// مقدمة اختبار المستوى. الاختبار نفسه يُبنى مع محتوى القرآن والعربية.
class LevelIntroScreen extends StatelessWidget {
  const LevelIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void next({required bool tookCheck}) {
      if (tookCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اختبار المستوى قيد الإعداد، سنبدأ من البداية الآن'),
          ),
        );
      }
      context.go('/onboarding/ready');
    }

    return OnboardingScaffold(
      step: 'الخطوة ٣ من ٣',
      canGoBack: false,
      title: 'لنتعرّف على مستوى طفلك',
      subtitle: 'دقيقتان فقط، بلا درجات ولا ضغط',
      child: Column(
        children: [
          const Spacer(),
          const Text('📝', style: TextStyle(fontSize: 96)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'ابدأ التعرّف',
              onPressed: () => next(tookCheck: true),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => next(tookCheck: false),
            child: const Text('تخطَّ الآن', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
