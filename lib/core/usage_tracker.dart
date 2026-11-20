import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../features/lessons/break_reminder.dart';
import '../domain/gamification/streak.dart';
import '../features/remote/remote_sync.dart';
import 'packs/pack_controls.dart';

/// يسجّل وقت الاستخدام الفعلي لكل طفلة (لتقرير ولي الأمر):
/// يعدّ فقط عندما يكون التطبيق ظاهرًا وهناك طفلة مختارة، كل 15 ثانية.
/// لا يُسجَّل شيء أثناء وجود ولي الأمر في لوحته (لا توجد طفلة مختارة).
class UsageTrackerScope extends ConsumerStatefulWidget {
  const UsageTrackerScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UsageTrackerScope> createState() => _UsageTrackerScopeState();
}

class _UsageTrackerScopeState extends ConsumerState<UsageTrackerScope>
    with WidgetsBindingObserver {
  static final bool _testMode = Platform.environment.containsKey('FLUTTER_TEST');
  static const Duration _tick = Duration(seconds: 15);

  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_tick, (_) => _record());
    // حزم الأصوات والتلاوة الإضافية: تنزيل هادئ بعد فتح التطبيق بقليل.
    if (!_testMode) unawaited(startPacksSoon(ref));
    // مدة الاستراحة من إعدادات ولي الأمر
    ref.read(settingsRepositoryProvider).timeSettings().then((t) {
      BreakReminder.interval = Duration(minutes: t.breakEveryMin.clamp(5, 60));
    }).catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // ترك التطبيق: نرسل آخر تقدم لتليفون الأهل (لو المتابعة مشغّلة).
    if (state == AppLifecycleState.paused) unawaited(ref.read(remoteSyncProvider).maybeSync(force: true));
  }

  Future<void> _record() async {
    if (!_foreground) return;
    // كل 5 دقائق على الأكثر: ملخص التقدم لتليفون الأهل (بصمت، ولا شيء لو مطفأة).
    unawaited(ref.read(remoteSyncProvider).maybeSync());
    final childId = ref.read(selectedChildIdProvider);
    if (childId == null) return;
    try {
      await ref
          .read(childRepositoryProvider)
          .addUsage(childId, _tick.inSeconds, dayKey(DateTime.now()));
    } catch (_) {
      // تتبّع الوقت ميزة إضافية ولا يجب أن يكسر التطبيق.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
