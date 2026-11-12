import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audioplayers_sound_player.dart';
import '../core/audio/sound_service.dart';
import '../domain/gamification/quests.dart';
import '../domain/gamification/streak.dart';
import 'content/content_repository.dart';
import 'content/lesson.dart';
import 'models/child.dart';
import 'models/child_report.dart';
import 'models/gamification.dart';
import 'repositories/child_repository.dart';
import 'repositories/gamification_repository.dart';
import 'repositories/settings_repository.dart';

final childRepositoryProvider = Provider((_) => ChildRepository());
final settingsRepositoryProvider = Provider((_) => SettingsRepository());

final childrenProvider = FutureProvider<List<Child>>(
  (ref) => ref.watch(childRepositoryProvider).all(),
);

/// الطفلة المختارة حاليًا (null = لم تُختر بعد).
final selectedChildIdProvider = StateProvider<int?>((_) => null);

final selectedChildProvider = FutureProvider<Child?>((ref) async {
  final id = ref.watch(selectedChildIdProvider);
  if (id == null) return null;
  return ref.watch(childRepositoryProvider).byId(id);
});

final gamificationRepositoryProvider = Provider((_) => GamificationRepository());

final gamificationProfileProvider =
    FutureProvider.family<GamificationProfile, int>((ref, childId) {
  return ref.watch(gamificationRepositoryProvider).profile(childId);
});

final completedLessonIdsProvider =
    FutureProvider.family<Set<String>, int>((ref, childId) {
  return ref.watch(gamificationRepositoryProvider).completedLessonIds(childId);
});

final earnedBadgesProvider =
    FutureProvider.family<Map<String, String>, int>((ref, childId) {
  return ref.watch(gamificationRepositoryProvider).earnedBadges(childId);
});

final dailyQuestsProvider =
    FutureProvider.family<DailyQuestsState, int>((ref, childId) {
  return ref.watch(gamificationRepositoryProvider).dailyQuests(childId);
});

/// تقرير ولي الأمر لطفلة واحدة (يجمع التقدم والمحتوى والاستخدام).
final childReportProvider =
    FutureProvider.family<ChildReport, int>((ref, childId) async {
  final children = ref.watch(childRepositoryProvider);
  final game = ref.watch(gamificationRepositoryProvider);
  final child = await children.byId(childId);
  if (child == null) throw StateError('child $childId not found');
  final lessons = await ref.watch(lessonsProvider.future);
  return ReportBuilder.build(
    child: child,
    profile: await game.profile(childId),
    lessons: lessons,
    progress: await game.progressEntries(childId),
    badgesEarned: (await game.earnedBadges(childId)).length,
    usageTodaySeconds: await children.usageSecondsOn(childId, dayKey(DateTime.now())),
    usageTotalSeconds: await children.totalSecondsUsed(childId),
    today: dayKey(DateTime.now()),
  );
});

final soundServiceProvider = Provider<SoundService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return SoundService(
    player: AudioplayersSoundPlayer(),
    readEnabled: settings.soundEnabled,
    writeEnabled: settings.setSoundEnabled,
  );
});

final soundEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).soundEnabled(),
);

final contentRepositoryProvider = Provider((_) => ContentRepository());

final lessonsProvider = FutureProvider<List<Lesson>>(
  (ref) => ref.watch(contentRepositoryProvider).loadLessons(),
);

final sectionStatesProvider = FutureProvider<Map<String, bool>>(
  (ref) => ref.watch(settingsRepositoryProvider).sectionStates(),
);
