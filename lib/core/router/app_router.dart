import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/home/journey_screen.dart';
import '../../features/home/section_screen.dart';
import '../../features/intro/intro_cinema_screen.dart';
import '../../features/intro/launch_gate.dart';
import '../../features/lessons/lesson_screen.dart';
import '../../features/parent/parent_dashboard_screen.dart';
import '../../features/parent/parent_gate_screen.dart';
import '../../features/today/today_screen.dart';

void _backToMain(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LaunchGate()),
      // 🎬 «إعادة مشاهدة المغامرة»: اختيارية، وتعود للشاشة الرئيسية.
      GoRoute(
        path: '/intro',
        builder: (context, __) => IntroCinemaScreen(
          onDone: () => _backToMain(context),
          onExit: (_) => _backToMain(context),
        ),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
      GoRoute(path: '/journey', builder: (_, __) => const JourneyScreen()),
      GoRoute(path: '/section/:id', builder: (_, state) => SectionScreen(sectionId: state.pathParameters['id']!)),
      GoRoute(path: '/lesson/:id', builder: (_, state) => LessonScreen(lessonId: state.pathParameters['id']!)),
      GoRoute(path: '/parent', builder: (_, __) => const ParentGateScreen()),
      GoRoute(path: '/parent/dashboard', builder: (_, __) => const ParentDashboardScreen()),
    ],
  );
});