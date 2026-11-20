import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/child_report.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/gamification/streak.dart';
import '../games/game_providers.dart';
import '../today/today_screen.dart' show curriculumProvider;
import 'remote_client.dart';
import 'remote_config.dart';
import 'remote_summary.dart';

/// يرسل ملخص التقدم من تليفون البنات إلى الخدمة، بهدوء:
/// لا يرمي أبدًا، ولا يرسل إلا لو الأهل شغّلوا المتابعة وفيه كود أسرة، وعلى الأكثر مرة كل [every].
/// لو مفيش نت يفشل بصمت ويحاول في المرة الجاية.
class RemoteSyncService {
  RemoteSyncService({
    required SettingsRepository settings,
    required RemoteClient client,
    required Future<FamilySummary> Function() summarize,
    bool Function()? configured,
    DateTime Function()? now,
  })  : _settings = settings,
        _client = client,
        _summarize = summarize,
        _configured = configured ?? (() => RemoteConfig.ready),
        _now = now ?? DateTime.now;

  final SettingsRepository _settings;
  final RemoteClient _client;
  final Future<FamilySummary> Function() _summarize;
  final bool Function() _configured;
  final DateTime Function() _now;

  static const every = Duration(minutes: 5);

  DateTime? _lastTry;
  bool _busy = false;

  /// يرسل الآن (زر «ابعتي دلوقتي»، أو بعد إنهاء درس). يرجع true لو وصل.
  Future<bool> syncNow() async {
    if (_busy) return false;
    _busy = true;
    try {
      if (!_configured()) return false;
      if (await _settings.deviceRole() != 'kids') return false;
      if (!await _settings.remoteSyncOn()) return false;
      final code = await _settings.familyCode();
      if (code == null) return false;
      _lastTry = _now();
      final ok = await _client.put(code, (await _summarize()).encode());
      if (ok) await _settings.setLastRemoteSync(_now());
      return ok;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// يرسل لو مرّ [every] على آخر محاولة (يُستدعى دوريًا وعند ترك التطبيق).
  Future<bool> maybeSync({bool force = false}) async {
    final last = _lastTry;
    if (!force && last != null && _now().difference(last) < every) return false;
    return syncNow();
  }
}

/// يجمع ملخص الأسرة من قاعدة البيانات (نفس أرقام تقرير لوحة الأهل).
Future<FamilySummary> gatherFamilySummary(Ref ref) async {
  final childrenRepo = ref.read(childRepositoryProvider);
  final game = ref.read(gamificationRepositoryProvider);
  final games = ref.read(gameRepositoryProvider);
  final settings = ref.read(settingsRepositoryProvider);
  final lessons = await ref.read(lessonsProvider.future);
  final curriculum = await ref.read(curriculumProvider.future);
  final now = DateTime.now();
  final today = dayKey(now);
  final out = <ChildSummary>[];
  for (final child in await childrenRepo.all()) {
    final report = ReportBuilder.build(
      child: child,
      profile: await game.profile(child.id),
      lessons: lessons,
      progress: await game.progressEntries(child.id),
      badgesEarned: (await game.earnedBadges(child.id)).length,
      usageTodaySeconds: await childrenRepo.usageSecondsOn(child.id, today),
      usageTotalSeconds: await childrenRepo.totalSecondsUsed(child.id),
      today: today,
    );
    final week = <int>[
      for (var i = 6; i >= 0; i--) await childrenRepo.usageSecondsOn(child.id, dayKey(now.subtract(Duration(days: i)))),
    ];
    final path = curriculum.pathFor(
      childAge: child.age,
      allLessons: lessons,
      completed: await game.completedLessonIds(child.id),
    );
    out.add(ChildSummary.build(
      report: report,
      path: path,
      weekSeconds: week,
      gamePlays: await games.totalPlays(child.id),
    ));
  }
  final limit = (await settings.timeSettings()).dailyLimitMin;
  return FamilySummary(children: out, dailyLimitMin: limit, madeAt: now);
}

final remoteClientProvider = Provider<RemoteClient>((_) => FirestoreRemoteClient());

final remoteSyncProvider = Provider<RemoteSyncService>((ref) => RemoteSyncService(
      settings: ref.watch(settingsRepositoryProvider),
      client: ref.watch(remoteClientProvider),
      summarize: () => gatherFamilySummary(ref),
    ));

final deviceRoleProvider = FutureProvider<String>((ref) => ref.watch(settingsRepositoryProvider).deviceRole());
final familyCodeProvider = FutureProvider<String?>((ref) => ref.watch(settingsRepositoryProvider).familyCode());
final remoteSyncOnProvider = FutureProvider<bool>((ref) => ref.watch(settingsRepositoryProvider).remoteSyncOn());
final lastRemoteSyncProvider = FutureProvider<DateTime?>((ref) => ref.watch(settingsRepositoryProvider).lastRemoteSync());
