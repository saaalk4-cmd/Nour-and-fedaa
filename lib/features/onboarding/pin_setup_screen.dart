import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pin_entry.dart';
import '../../data/providers.dart';
import 'onboarding_scaffold.dart';

/// اختيار رمز ولي الأمر (٤ أرقام) مع تأكيده.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _first;
  String? _error;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'الرمزان غير متطابقين، حاول من جديد';
      });
      return;
    }
    await ref.read(settingsRepositoryProvider).setPin(pin);
    if (mounted) context.go('/onboarding/child');
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return OnboardingScaffold(
      step: 'الخطوة ١ من ٣',
      title: confirming ? 'أعد إدخال الرمز' : 'اختر رمزًا سريًا',
      subtitle: 'يحمي إعدادات ولي الأمر من الأطفال',
      canGoBack: false,
      child: Center(
        child: SingleChildScrollView(
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: AppColors.navy,
                  ),
            ),
            child: PinEntry(onCompleted: _onPin, error: _error),
          ),
        ),
      ),
    );
  }
}
