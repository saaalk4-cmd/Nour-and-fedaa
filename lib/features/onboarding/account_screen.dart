import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/parent_account.dart';
import '../../data/providers.dart';
import 'onboarding_scaffold.dart';

/// تنبيه يظهر ما دام الحساب محليًا (قبل ربط Firebase).
const kLocalAccountNotice =
    'وضع تجريبي: الحساب محفوظ على هذا الجهاز فقط، ويُربط بحساب حقيقي عند تفعيل Firebase.';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    SignInMethod method, {
    String? email,
  }) async {
    await ref.read(accountRepositoryProvider).signIn(method, email: email);
    ref.invalidate(accountProvider);
    if (context.mounted) context.go('/onboarding/pin');
  }

  Future<void> _askEmail(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('البريد الإلكتروني'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.contains('@') && v.contains('.')) Navigator.pop(ctx, v);
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email != null && context.mounted) {
      await _signIn(context, ref, SignInMethod.email, email: email);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScaffold(
      title: 'حساب ولي الأمر',
      subtitle: 'أنت من يدير الحساب ويتابع التقدّم',
      child: Column(
        children: [
          const SizedBox(height: 24),
          _AccountButton(
            icon: Icons.account_circle_outlined,
            label: 'المتابعة بحساب جوجل',
            onTap: () => _signIn(context, ref, SignInMethod.google),
          ),
          const SizedBox(height: 16),
          _AccountButton(
            icon: Icons.mail_outline,
            label: 'المتابعة بالبريد الإلكتروني',
            onTap: () => _askEmail(context, ref),
          ),
          const Spacer(),
          Text(
            kLocalAccountNotice,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
