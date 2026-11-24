import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// يعدّ وقت استخدام الطفل المختار (والتطبيق في الواجهة) ويحفظه كل [tick].
class UsageTracker extends ConsumerStatefulWidget {
  const UsageTracker({
    super.key,
    required this.child,
    this.tick = const Duration(seconds: 15),
    this.secondsPerTick,
  });

  final Widget child;
  final Duration tick;

  /// الثواني المضافة في كل نبضة (الافتراضي: مدة النبضة، وللاختبار فقط يمكن تغييره).
  final int? secondsPerTick;

  @override
  ConsumerState<UsageTracker> createState() => _UsageTrackerState();
}

class _UsageTrackerState extends ConsumerState<UsageTracker>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _resumed = true;
  int? _loadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.tick, (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
  }

  Future<void> _onTick() async {
    final id = ref.read(selectedChildIdProvider);
    if (id == null || !_resumed || ref.read(usagePausedProvider)) return;
    final repo = ref.read(usageRepositoryProvider);
    final secs = widget.secondsPerTick ?? widget.tick.inSeconds;
    await repo.add(id, secs);
    final today = await repo.secondsOn(id, DateTime.now());
    if (mounted) ref.read(todaySecondsProvider.notifier).state = today;
  }

  Future<void> _loadFor(int? id) async {
    if (id == _loadedFor) return;
    _loadedFor = id;
    if (id == null) {
      ref.read(todaySecondsProvider.notifier).state = 0;
      return;
    }
    final today = await ref.read(usageRepositoryProvider).secondsOn(id, DateTime.now());
    if (mounted && _loadedFor == id) {
      ref.read(todaySecondsProvider.notifier).state = today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedChildIdProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFor(id));
    return widget.child;
  }
}
