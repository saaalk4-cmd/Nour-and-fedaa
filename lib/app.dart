import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rest_gate.dart';
import 'core/router/app_router.dart';
import 'data/providers.dart';
import 'core/usage_tracker.dart';
import 'core/theme/app_theme.dart';

class NourFadaaApp extends ConsumerWidget {
  const NourFadaaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'نُور وفداء',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final scale = ref.watch(fontScaleProvider).valueOrNull ?? 1.0;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * scale)),
          child: UsageTrackerScope(child: RestGate(child: child ?? const SizedBox.shrink())),
        );
      },
    );
  }
}
