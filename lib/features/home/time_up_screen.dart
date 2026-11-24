import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// تظهر عند بلوغ الحد اليومي: لطيفة وبلا لوم، والتمديد من لوحة ولي الأمر.
class TimeUpScreen extends StatelessWidget {
  const TimeUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text('🌙', style: TextStyle(fontSize: 110)),
              const SizedBox(height: 24),
              const Text(
                'انتهى وقت اليوم',
                style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 32,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'نلتقي غدًا إن شاء الله، جرّبوا نشاطًا معًا بعيدًا عن الشاشة',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.cream, fontSize: 18),
              ),
              const Spacer(),
              TextButton(
                key: const Key('timeup_parent'),
                onPressed: () => context.push('/parent'),
                child: const Text('ولي الأمر',
                    style: TextStyle(color: AppColors.gold, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
