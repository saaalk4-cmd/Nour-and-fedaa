import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/home/journey_screen.dart';
import '../../features/home/section_screen.dart';
import '../../features/intro/intro_audio_player.dart';
import '../../features/intro/intro_experience.dart';
import '../../features/intro/launch_gate.dart';
import '../../features/lessons/lesson_screen.dart';
import '../../features/path/learning_path_screen.dart';
import '../../features/parent/parent_dashboard_screen.dart';
import '../../features/parent/parent_gate_screen.dart';
import '../../features/parent/voice/voice_studio_screen.dart';
import '../../features/parent/hifz_edit_screen.dart';
import '../../features/world/world_map.dart';
import '../../features/remote/remote_view_screen.dart';
import '../../features/song/song_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/games/game_play_screen.dart';
import '../../features/games/games_home_screen.dart';
import '../../features/world/world_screen.dart';

void _backToMain(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// أي انتقال بين الشاشات يوقف الكلام والتلاوة الجارية فورًا (فلا تتداخل جملتان أبدًا).
class _StopSpeechObserver extends NavigatorObserver {
  _StopSpeechObserver(this._stop);

  final void Function() _stop;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _stop();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _stop();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    observers: [
      _StopSpeechObserver(() {
        ref.read(voiceServiceProvider).stop();
        ref.read(ayahPlayerProvider).stop();
      }),
    ],
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LaunchGate()),
      // 🎬 «إعادة مشاهدة المغامرة»: اختيارية، وتعود للشاشة الرئيسية.
      GoRoute(
        path: '/intro',
        builder: (context, __) => IntroExperience(
          audio: AssetIntroAudio(),
          onDone: () => _backToMain(context),
          onExit: (_) => _backToMain(context),
        ),
      ),
      GoRoute(path: '/path', builder: (_, __) => const LearningPathScreen()),
      GoRoute(path: '/world', builder: (_, __) => const WorldScreen()),
      GoRoute(path: '/world/deen', builder: (_, __) => const DeenScreen()),
      GoRoute(path: '/world/map', builder: (_, __) => const WorldMapScreen()),
      GoRoute(path: '/games', builder: (_, __) => const GamesHomeScreen()),
      GoRoute(path: '/games/:id', builder: (_, s) => GameLevelsScreen(gameId: s.pathParameters['id']!)),
      GoRoute(
        path: '/games/:id/play/:level',
        builder: (_, s) => GamePlayScreen(gameId: s.pathParameters['id']!, levelKey: s.pathParameters['level']!),
      ),
      // المسار القديم «العب بحرية» صار جزءًا من «عالمنا».
      GoRoute(path: '/home', redirect: (_, __) => '/world'),
      GoRoute(path: '/song', builder: (_, s) => SongScreen(celebrate: s.uri.queryParameters['celebrate'] == '1')),
      GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
      GoRoute(path: '/journey', builder: (_, __) => const JourneyScreen()),
      GoRoute(path: '/section/:id', builder: (_, state) => SectionScreen(sectionId: state.pathParameters['id']!)),
      GoRoute(path: '/lesson/:id', builder: (_, state) => LessonScreen(lessonId: state.pathParameters['id']!)),
      GoRoute(path: '/parent', builder: (_, __) => const ParentGateScreen()),
      GoRoute(path: '/remote', builder: (_, __) => const RemoteViewScreen()),
      GoRoute(path: '/parent/dashboard', builder: (_, __) => const ParentDashboardScreen()),
      GoRoute(path: '/parent/voice', builder: (_, __) => const VoiceStudioScreen()),
      GoRoute(path: '/parent/hifz/:id', builder: (_, s) => HifzEditScreen(childId: int.parse(s.pathParameters['id']!))),
    ],
  );
});