import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// بوابة لوحة ولي الأمر: إنشاء رمز PIN أول مرة، ثم التحقق منه.
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key});

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool? _hasPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).hasPin().then((v) {
      if (mounted) setState(() => _hasPin = v);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = ref.read(settingsRepositoryProvider);
    final pin = _pin.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'الرمز يتكون من 4 أرقام');
      return;
    }
    if (_hasPin == true) {
      final ok = await repo.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        context.pushReplacement('/parent/dashboard');
      } else {
        setState(() => _error = 'الرمز غير صحيح');
      }
    } else {
      if (pin != _confirm.text.trim()) {
        setState(() => _error = 'الرمزان غير متطابقين');
        return;
      }
      await repo.setPin(pin);
      if (!mounted) return;
      context.pushReplacement('/parent/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = _hasPin == false;
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة ولي الأمر')),
      body: _hasPin == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    creating ? 'أنشئ رمز PIN من 4 أرقام' : 'أدخل رمز PIN',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  _PinField(controller: _pin, label: 'الرمز'),
                  if (creating) ...[
                    const SizedBox(height: 16),
                    _PinField(controller: _confirm, label: 'تأكيد الرمز'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(creating ? 'حفظ' : 'دخول'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 28, letterSpacing: 8),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
