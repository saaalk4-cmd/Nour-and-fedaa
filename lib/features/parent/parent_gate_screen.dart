import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

/// بوابة لوحة ولي الأمر: إنشاء رمز PIN أول مرة (مع تأكيد)، ثم التحقق منه بلوحة أرقام كبيرة.
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key});

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  bool? _hasPin;
  String _entry = '';
  String? _first; // الرمز الأول أثناء الإنشاء، بانتظار التأكيد.
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).hasPin().then((v) {
      if (mounted) setState(() => _hasPin = v);
    });
  }

  bool get _creating => _hasPin == false;

  String get _title {
    if (!_creating) return 'أدخل رمز PIN';
    return _first == null ? 'أنشئ رمز PIN من 4 أرقام' : 'أعد كتابة الرمز للتأكيد';
  }

  void _press(String d) {
    if (_entry.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 4) _submit();
  }

  void _back() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    final repo = ref.read(settingsRepositoryProvider);
    final pin = _entry;
    if (!_creating) {
      final ok = await repo.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        context.pushReplacement('/parent/dashboard');
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'الرمز غير صحيح';
          _entry = '';
        });
      }
      return;
    }
    if (_first == null) {
      setState(() {
        _first = pin;
        _entry = '';
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _error = 'الرمزان غير متطابقين، ابدأ من جديد';
        _first = null;
        _entry = '';
      });
      return;
    }
    await repo.setPin(pin);
    if (!mounted) return;
    context.pushReplacement('/parent/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: _hasPin == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF4FC3D9), Color(0xFF2A9D8F)]),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 50),
                    ),
                    const SizedBox(height: 14),
                    Text(_title, style: AppText.display(26)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 4; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 9),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _entry.length ? AppColors.teal : Colors.white,
                              border: Border.all(color: AppColors.teal, width: 3),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 36,
                      child: _error == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w700),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    _Keypad(onDigit: _press, onBack: _back),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack});

  final void Function(String) onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: PopTap(
              haptic: false,
              onTap: onTap,
              child: Container(
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onTap == null ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: onTap == null
                      ? const []
                      : const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: child ?? Text(label, style: AppText.display(32)),
              ),
            ),
          ),
        );
    Widget row(List<String> digits) => Row(
          children: [for (final d in digits) key(d, onTap: () => onDigit(d))],
        );
    return Column(
      children: [
        row(const ['1', '2', '3']),
        row(const ['4', '5', '6']),
        row(const ['7', '8', '9']),
        Row(
          children: [
            key('', onTap: null),
            key('0', onTap: () => onDigit('0')),
            key('', onTap: onBack, child: const Icon(Icons.backspace_rounded, size: 30, color: AppColors.ink)),
          ],
        ),
      ],
    );
  }
}
