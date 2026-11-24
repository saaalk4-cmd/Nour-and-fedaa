import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/age_band.dart';
import 'onboarding_scaffold.dart';

/// مقدمة اختبار المستوى. البراعم (٢–٤) بلا اختبار: يبدؤون من البداية.
class LevelIntroScreen extends ConsumerWidget {
  const LevelIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider).valueOrNull;
    final noCheck = child?.band() == AgeBand.buraem;

    return OnboardingScaffold(
      step: 'الخطوة ٣ من ٣',
      canGoBack: false,
      title: noCheck ? 'سنبدأ من البداية' : 'لنتعرّف على مستوى طفلك',
      subtitle: noCheck
          ? 'فئة البراعم بلا اختبار، يتعلّم الطفل بالاستماع واللعب'
          : 'دقيقتان فقط، بلا درجات ولا ضغط',
      child: Column(
        children: [
          const Spacer(),
          Text(noCheck ? '🌱' : '📝', style: const TextStyle(fontSize: 96)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: noCheck ? 'متابعة' : 'ابدأ التعرّف',
              onPressed: () => context
                  .go(noCheck ? '/onboarding/ready' : '/onboarding/check'),
            ),
          ),
          const SizedBox(height: 8),
          if (!noCheck)
            TextButton(
              onPressed: () => context.go('/onboarding/ready'),
              child: const Text('تخطَّ الآن', style: TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
  }
}
