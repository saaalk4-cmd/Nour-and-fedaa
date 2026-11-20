import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audioplayers_sound_player.dart';
import '../core/audio/ayah_player.dart';
import '../core/audio/flutter_tts_engine.dart';
import '../core/audio/asset_clip_player.dart';
import '../core/audio/user_voice_store.dart';
import '../core/audio/voice_service.dart';
import '../core/audio/sound_service.dart';
import '../domain/gamification/quests.dart';
import '../domain/gamification/streak.dart';
import 'content/ayah_index.dart';
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

final progressEntriesProvider =
    FutureProvider.family<List<ProgressEntry>, int>((ref, childId) {
  return ref.watch(gamificationRepositoryProvider).progressEntries(childId);
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
  final svc = SoundService(
    player: AudioplayersSoundPlayer(),
    readEnabled: settings.soundEnabled,
    writeEnabled: settings.setSoundEnabled,
  );
  unawaited(settings.voiceSettings().then<void>((v) => svc.effectsVolume = v.effectsVolume).catchError((Object _) {}));
  return svc;
});

/// محرك صوت الجهاز (مشترك لتعرض لوحة الأهل الأصوات المتاحة وتغيّرها).
final ttsEngineProvider = Provider<FlutterTtsEngine>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return FlutterTtsEngine(preferredVoice: settings.ttsVoice);
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return VoiceService(
    engine: ref.watch(ttsEngineProvider),
    clips: AssetClipPlayer(),
    userVoice: ref.watch(userVoiceProvider),
    readSettings: settings.voiceSettings,
    readEnabled: settings.voiceEnabled,
    writeEnabled: settings.setVoiceEnabled,
  );
});

/// تسجيلات صوت الأهل (تُنفَّذ في recorded_voice.dart).
final userVoiceProvider = Provider<UserVoice?>((_) => UserVoiceStore.instance);

final voiceSettingsProvider = FutureProvider<VoiceSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).voiceSettings(),
);

final reduceMotionProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).reduceMotion(),
);

final fontScaleProvider = FutureProvider<double>(
  (ref) => ref.watch(settingsRepositoryProvider).fontScale(),
);

final voiceEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).voiceEnabled(),
);

final ayahPlayerProvider = Provider<AyahPlayer>((ref) {
  final player = AyahPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final soundEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).soundEnabled(),
);

final contentRepositoryProvider = Provider((_) => ContentRepository());

final lessonsProvider = FutureProvider<List<Lesson>>(
  (ref) => ref.watch(contentRepositoryProvider).loadLessons(),
);

/// نص الآية → تلاوتها (للأسئلة والاختيارات المسموعة).
final ayahIndexProvider = FutureProvider<AyahIndex>((_) => AyahIndex.load());

final sectionStatesProvider = FutureProvider<Map<String, bool>>(
  (ref) => ref.watch(settingsRepositoryProvider).sectionStates(),
);
