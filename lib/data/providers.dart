import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/child.dart';
import 'models/parent_account.dart';
import 'repositories/account_repository.dart';
import '../domain/age_band.dart';
import '../domain/lesson.dart';
import 'repositories/badge_repository.dart';
import 'repositories/child_repository.dart';
import 'repositories/lesson_repository.dart';
import 'repositories/placement_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';
import '../domain/course_session.dart';
import 'repositories/usage_repository.dart';
import '../domain/hadith.dart';
import 'quran/quran_player.dart';
import 'quran/quran_source.dart';
import 'quran/sqlite_quran_cache.dart';
import 'repositories/hadith_repository.dart';
import 'sync/cloud_store.dart';
import 'sync/sync_service.dart';

final childRepositoryProvider = Provider((_) => ChildRepository());
final settingsRepositoryProvider = Provider((_) => SettingsRepository());
final lessonRepositoryProvider = Provider((_) => LessonRepository());
final placementRepositoryProvider = Provider((_) => PlacementRepository());
final badgeRepositoryProvider = Provider((_) => BadgeRepository());
final progressRepositoryProvider = Provider((_) => ProgressRepository());

final lessonProvider = FutureProvider.family<Lesson, String>(
  (ref, id) => ref.watch(lessonRepositoryProvider).byId(id),
);

/// هل نجحت تهيئة Firebase عند الإقلاع؟ (يُضبط في main).
final firebaseReadyProvider = Provider<bool>((_) => false);

final accountRepositoryProvider = Provider<AccountRepository>((ref) =>
    ref.watch(firebaseReadyProvider)
        ? FirebaseAccountRepository()
        : LocalAccountRepository(ref.watch(settingsRepositoryProvider)));

final accountProvider = FutureProvider<ParentAccount?>(
  (ref) => ref.watch(accountRepositoryProvider).current(),
);

final childrenProvider = FutureProvider<List<Child>>(
  (ref) => ref.watch(childRepositoryProvider).all(),
);

/// الطفل المختار حاليًا (null = لم يُختر بعد).
final selectedChildIdProvider = StateProvider<int?>((_) => null);

final selectedChildProvider = FutureProvider<Child?>((ref) async {
  final id = ref.watch(selectedChildIdProvider);
  if (id == null) return null;
  return ref.watch(childRepositoryProvider).byId(id);
});

final sectionStatesProvider = FutureProvider<Map<String, bool>>(
  (ref) => ref.watch(settingsRepositoryProvider).sectionStates(),
);

/// بيانات الطفل أثناء رحلة التسجيل.
final childDraftProvider = StateProvider<ChildDraft>((_) => const ChildDraft());

final usageRepositoryProvider = Provider((_) => UsageRepository());

final dailyLimitProvider = FutureProvider<int>(
  (ref) => ref.watch(settingsRepositoryProvider).dailyLimitMinutes(),
);

/// ثواني استخدام الطفل المختار اليوم (يحدّثها UsageTracker).
final todaySecondsProvider = StateProvider<int>((_) => 0);

/// يوقف عدّ الوقت (مثلًا أثناء وجود ولي الأمر في لوحته).
final usagePausedProvider = StateProvider<bool>((_) => false);

/// هل بلغ الطفل المختار حده اليومي؟
final limitReachedProvider = Provider<bool>((ref) {
  final limit = ref.watch(dailyLimitProvider).valueOrNull ?? 0;
  if (limit <= 0) return false;
  return ref.watch(todaySecondsProvider) >= limit * 60;
});

/// دروس قسم معيّن للفئة المحددة.
final sectionLessonsProvider =
    FutureProvider.autoDispose.family<List<Lesson>, ({String section, AgeBand band})>(
  (ref, k) => ref.watch(lessonRepositoryProvider).bySection(k.section, k.band),
);

final reviewRepositoryProvider = Provider((_) => ReviewRepository());

/// الدروس المستحقة للمراجعة اليوم للطفل المختار.
final dueReviewProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final id = ref.watch(selectedChildIdProvider);
  if (id == null) return const [];
  return ref.watch(reviewRepositoryProvider).due(id);
});

final cloudStoreProvider = Provider<CloudStore>((_) => FirestoreCloudStore());

/// خدمة المزامنة للحساب الحقيقي الحالي، أو null (وضع محلي / لم يُسجَّل الدخول).
final syncServiceProvider = Provider<SyncService?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final acc = ref.watch(accountProvider).valueOrNull;
  if (acc == null || acc.uid == null) return null;
  return SyncService(uid: acc.uid!, store: ref.watch(cloudStoreProvider));
});


final quranSourceProvider = Provider<QuranSource>((_) =>
    CachingQuranSource(remote: AlQuranCloudSource(), cache: SqliteQuranCache()));

final quranPlayerProvider = Provider<QuranPlayer>((ref) {
  final p = AudioQuranPlayer();
  ref.onDispose(p.stop);
  return p;
});

final surahProvider = FutureProvider.family<Surah, int>(
  (ref, n) => ref.watch(quranSourceProvider).surah(n),
);

final hadithRepositoryProvider = Provider((_) => HadithRepository());

final hadithProvider = FutureProvider.family<Hadith, String>(
  (ref, id) => ref.watch(hadithRepositoryProvider).byId(id),
);

final sessionRepositoryProvider = Provider((_) => SessionRepository());

/// حصة اليوم للطفل المختار مع الدروس التي أتمّها (null = لا منهج لفئته بعد).
final todaySessionProvider = FutureProvider.autoDispose<
    ({CourseSession session, Set<String> done, int total})?>((ref) async {
  final child = await ref.watch(selectedChildProvider.future);
  if (child == null) return null;
  final all = await ref.watch(sessionRepositoryProvider).forBand(child.band());
  final done = {
    for (final (id, _) in await ref.watch(progressRepositoryProvider).completed(child.id)) id
  };
  final today = pickTodaySession(all, done);
  if (today == null) return null;
  return (session: today, done: done, total: all.length);
});

/// حصة بعينها برقمها.
final sessionByNumberProvider = FutureProvider.autoDispose
    .family<({CourseSession session, Set<String> done})?, int>((ref, n) async {
  final child = await ref.watch(selectedChildProvider.future);
  if (child == null) return null;
  final all = await ref.watch(sessionRepositoryProvider).forBand(child.band());
  if (n < 1 || n > all.length) return null;
  final done = {
    for (final (id, _) in await ref.watch(progressRepositoryProvider).completed(child.id)) id
  };
  return (session: all[n - 1], done: done);
});
