import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../data/repositories/account_repository.dart';
import 'onboarding_scaffold.dart';

/// تنبيه يظهر ما دام الحساب محليًا (حين لا يتوفر Firebase).
const kLocalAccountNotice =
    'وضع تجريبي: الحساب محفوظ على هذا الجهاز فقط، ويُربط بحساب حقيقي عند تفعيل Firebase.';

/// حساب ولي الأمر: إنشاء حساب أو دخول بالبريد وكلمة المرور.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _newAccount = true;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final e = _email.text.trim();
    if (!e.contains('@') || !e.contains('.')) return 'البريد الإلكتروني غير صحيح';
    if (_password.text.length < 6) return 'كلمة المرور ٦ أحرف على الأقل';
    return null;
  }

  Future<void> _submit() async {
    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final repo = ref.read(accountRepositoryProvider);
    try {
      final email = _email.text.trim();
      if (_newAccount) {
        await repo.signUpWithEmail(email, _password.text);
      } else {
        await repo.signInWithEmail(email, _password.text);
      }
      ref.invalidate(accountProvider);
      if (mounted) context.go('/onboarding/pin');
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final e = _email.text.trim();
    if (!e.contains('@')) {
      setState(() => _error = 'اكتب بريدك أولًا ثم اضغط «نسيت كلمة المرور»');
      return;
    }
    try {
      await ref.read(accountRepositoryProvider).sendPasswordReset(e);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'أرسلنا رابط تغيير كلمة المرور إلى بريدك';
        });
      }
    } on AccountException catch (err) {
      if (mounted) setState(() => _error = err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReal = ref.watch(accountRepositoryProvider).isReal;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        );

    return OnboardingScaffold(
      title: 'حساب ولي الأمر',
      subtitle: 'أنت من يدير الحساب ويتابع التقدّم',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('حساب جديد')),
                ButtonSegment(value: false, label: Text('لدي حساب')),
              ],
              selected: {_newAccount},
              onSelectionChanged: (s) => setState(() {
                _newAccount = s.first;
                _error = null;
                _info = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('email_field'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: deco('البريد الإلكتروني'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('password_field'),
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              autofillHints: [
                _newAccount ? AutofillHints.newPassword : AutofillHints.password
              ],
              decoration: deco('كلمة المرور (٦ أحرف على الأقل)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  key: const Key('account_error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.terracotta, fontSize: 16)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Text(_info!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            GoldButton(
              label: _busy
                  ? '...'
                  : (_newAccount ? 'إنشاء الحساب' : 'الدخول'),
              onPressed: _busy ? null : _submit,
            ),
            if (!_newAccount)
              TextButton(
                onPressed: _busy ? null : _forgot,
                child: const Text('نسيت كلمة المرور'),
              ),
            const SizedBox(height: 12),
            const Text(
              'الدخول بحساب جوجل قريبًا إن شاء الله',
              textAlign: TextAlign.center,
            ),
            if (!isReal) ...[
              const SizedBox(height: 16),
              Text(
                kLocalAccountNotice,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
