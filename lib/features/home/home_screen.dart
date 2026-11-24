import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/age_band.dart';
import 'kids_home.dart';
import 'time_up_screen.dart';
import 'teen_home.dart';
import 'toddler_home.dart';
import 'tween_home.dart';

/// الرئيسية: تختار الواجهة حسب فئة الطفل العمرية.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final states =
        ref.watch(sectionStatesProvider).valueOrNull ?? const <String, bool>{};

    return child.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('حدث خطأ'))),
      data: (c) {
        if (c == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (ref.watch(limitReachedProvider)) return const TimeUpScreen();
        return homeForBand(c, states);
      },
    );
  }
}

/// تُستخدم أيضًا في الاختبارات.
Widget homeForBand(Child c, Map<String, bool> enabled) {
  switch (c.band()) {
    case AgeBand.buraem:
      return ToddlerHome(child: c);
    case AgeBand.atfal:
      return KidsHome(child: c, enabled: enabled);
    case AgeBand.nashia:
      return TweenHome(child: c, enabled: enabled);
    case AgeBand.murahiqun:
      return TeenHome(child: c, enabled: enabled);
  }
}
