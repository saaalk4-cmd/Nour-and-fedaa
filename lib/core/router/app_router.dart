import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/journey_screen.dart';
import '../../features/home/section_screen.dart';
import '../../features/home/who_learns_screen.dart';
import '../../features/lessons/lesson_screen.dart';
import '../../features/parent/parent_dashboard_screen.dart';
import '../../features/parent/parent_gate_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WhoLearnsScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/journey', builder: (_, __) => const JourneyScreen()),
      GoRoute(path: '/section/:id', builder: (_, state) => SectionScreen(sectionId: state.pathParameters['id']!)),
      GoRoute(path: '/lesson/:id', builder: (_, state) => LessonScreen(lessonId: state.pathParameters['id']!)),
      GoRoute(path: '/parent', builder: (_, __) => const ParentGateScreen()),
      GoRoute(path: '/parent/dashboard', builder: (_, __) => const ParentDashboardScreen()),
    ],
  );
});