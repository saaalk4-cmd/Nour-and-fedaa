import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/boot/boot_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/section_screen.dart';
import '../../features/home/who_learns_screen.dart';
import '../../features/lesson/lesson_screen.dart';
import '../../features/session/session_screen.dart';
import '../../features/onboarding/account_screen.dart';
import '../../features/onboarding/add_child_screen.dart';
import '../../features/onboarding/band_confirm_screen.dart';
import '../../features/onboarding/level_check_screen.dart';
import '../../features/onboarding/level_intro_screen.dart';
import '../../features/onboarding/pin_setup_screen.dart';
import '../../features/onboarding/ready_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/parent/change_pin_screen.dart';
import '../../features/parent/child_report_screen.dart';
import '../../features/parent/parent_dashboard_screen.dart';
import '../../features/parent/parents_corner_screen.dart';
import '../../features/parent/parent_gate_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const BootScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/onboarding/account',
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: '/onboarding/pin',
        builder: (_, __) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/child',
        builder: (_, __) => const AddChildScreen(),
      ),
      GoRoute(
        path: '/onboarding/band',
        builder: (_, __) => const BandConfirmScreen(),
      ),
      GoRoute(
        path: '/onboarding/level',
        builder: (_, __) => const LevelIntroScreen(),
      ),
      GoRoute(
        path: '/onboarding/check',
        builder: (_, state) => LevelCheckScreen(
            returnTo: state.uri.queryParameters['return']),
      ),
      GoRoute(
        path: '/onboarding/ready',
        builder: (_, __) => const ReadyScreen(),
      ),
      GoRoute(path: '/who', builder: (_, __) => const WhoLearnsScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/section/:id',
        builder: (_, state) =>
            SectionScreen(sectionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) => LessonScreen(
          lessonId: state.pathParameters['id']!,
          review: state.uri.queryParameters['review'] == '1',
        ),
      ),
      GoRoute(
        path: '/session/:n',
        builder: (_, state) =>
            SessionScreen(number: int.parse(state.pathParameters['n']!)),
      ),
      GoRoute(path: '/parent', builder: (_, __) => const ParentGateScreen()),
      GoRoute(
        path: '/parent/about',
        builder: (_, __) => const ParentsCornerScreen(),
      ),
      GoRoute(
        path: '/parent/pin',
        builder: (_, __) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/parent/report/:id',
        builder: (_, state) =>
            ChildReportScreen(childId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/parent/dashboard',
        builder: (_, __) => const ParentDashboardScreen(),
      ),
    ],
  );
});
