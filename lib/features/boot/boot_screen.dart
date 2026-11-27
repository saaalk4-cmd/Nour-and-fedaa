import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_service.dart';

/// شاشة البداية: تقرر أين يذهب المستخدم حسب ما أُنجز من التسجيل.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final account = await ref.read(accountProvider.future);
    final sync = ref.read(syncServiceProvider);
    if (sync != null) {
      try {
        await sync.pull().timeout(const Duration(seconds: 8));
      } catch (_) {
        // بلا إنترنت: نكمل بالبيانات المحلية.
      }
      SyncService.quietly(sync.pushAll);
    }
    final hasPin = await ref.read(settingsRepositoryProvider).hasPin();
    final children = await ref.read(childRepositoryProvider).all();
    if (!mounted) return;

    if (account == null) return context.go('/welcome');
    if (!hasPin) return context.go('/onboarding/pin');
    if (children.isEmpty) return context.go('/onboarding/child');
    if (children.length == 1) {
      ref.read(selectedChildIdProvider.notifier).state = children.first.id;
      return context.go('/home');
    }
    context.go('/who');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(child: BrandMark(width: 160)),
    );
  }
}
