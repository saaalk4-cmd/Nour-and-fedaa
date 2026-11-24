import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pin_entry.dart';
import '../../data/providers.dart';

/// بوابة لوحة ولي الأمر: التحقق من الرمز (يُنشأ أثناء التسجيل).
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key});

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  String? _error;

  Future<void> _verify(String pin) async {
    final ok = await ref.read(settingsRepositoryProvider).verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      context.pushReplacement('/parent/dashboard');
    } else {
      setState(() => _error = 'الرمز غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل رمز ولي الأمر',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              PinEntry(onCompleted: _verify, error: _error),
            ],
          ),
        ),
      ),
    );
  }
}
