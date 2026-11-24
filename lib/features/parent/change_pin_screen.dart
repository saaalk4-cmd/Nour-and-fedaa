import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pin_entry.dart';
import '../../data/providers.dart';

enum _Step { current, fresh, confirm }

/// تغيير رمز ولي الأمر: الحالي ← الجديد ← تأكيد الجديد.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.current;
  String? _fresh;
  String? _error;

  Future<void> _onPin(String pin) async {
    final repo = ref.read(settingsRepositoryProvider);
    switch (_step) {
      case _Step.current:
        if (await repo.verifyPin(pin)) {
          setState(() {
            _step = _Step.fresh;
            _error = null;
          });
        } else {
          setState(() => _error = 'الرمز الحالي غير صحيح');
        }
      case _Step.fresh:
        setState(() {
          _fresh = pin;
          _step = _Step.confirm;
          _error = null;
        });
      case _Step.confirm:
        if (pin != _fresh) {
          setState(() {
            _fresh = null;
            _step = _Step.fresh;
            _error = 'الرمزان غير متطابقين، حاول من جديد';
          });
          return;
        }
        await repo.setPin(pin);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تغيير الرمز')));
        Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.current => 'أدخل الرمز الحالي',
      _Step.fresh => 'اختر رمزًا جديدًا',
      _Step.confirm => 'أعد إدخال الرمز الجديد',
    };
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('تغيير الرمز السري')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              PinEntry(onCompleted: _onPin, error: _error),
            ],
          ),
        ),
      ),
    );
  }
}
