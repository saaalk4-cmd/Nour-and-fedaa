import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/gamification/streak.dart';
import '../domain/time_guard.dart';
import 'design/art.dart';
import 'design/kit.dart';
import 'router/app_router.dart';

/// «يلا نرتاح»: حين ينتهي الحد اليومي (أو يحين وقت ممنوع) تظهر هذه الشاشة اللطيفة بصوت لَمعة،
/// بدل أن يُقفل التطبيق فجأة. ولي الأمر (برمز PIN) يستطيع إضافة وقت أو السماح لباقي اليوم.
class RestGate extends ConsumerStatefulWidget {
  const RestGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RestGate> createState() => _RestGateState();
}

class _RestGateState extends ConsumerState<RestGate> {
  Timer? _timer;
  RestReason? _reason;
  bool _spoken = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final childId = ref.read(selectedChildIdProvider);
    RestReason? r;
    if (childId != null) {
      try {
        final repo = ref.read(settingsRepositoryProvider);
        final now = DateTime.now();
        final day = dayKey(now);
        final settings = await repo.timeSettings();
        r = checkRest(
          settings: settings,
          usedSeconds: await ref.read(childRepositoryProvider).usageSecondsOn(childId, day),
          extraMin: await repo.extraMinutes(day),
          overriddenToday: await repo.overriddenToday(day),
          now: now,
        );
      } catch (_) {
        r = null; // لا نمنع الطفلة بسبب عطل في القراءة
      }
    }
    if (!mounted) return;
    if (r != _reason) {
      setState(() {
        _reason = r;
        _spoken = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(selectedChildIdProvider, (_, __) => _check());
    final child = ref.watch(selectedChildProvider).valueOrNull;
    return Stack(
      children: [
        widget.child,
        if (_reason != null && child != null)
          Positioned.fill(
            child: _RestScreen(
              name: child.name,
              reason: _reason!,
              speak: !_spoken,
              onSpoken: () => _spoken = true,
              onLeave: () {
                ref.read(selectedChildIdProvider.notifier).state = null;
                ref.read(routerProvider).go('/');
                setState(() => _reason = null);
              },
              onGranted: () {
                ref.read(voiceServiceProvider).stop();
                setState(() => _reason = null);
                _check();
              },
            ),
          ),
      ],
    );
  }
}

class _RestScreen extends ConsumerStatefulWidget {
  const _RestScreen({required this.name, required this.reason, required this.speak, required this.onSpoken, required this.onLeave, required this.onGranted});

  final String name;
  final RestReason reason;
  final bool speak;
  final VoidCallback onSpoken;
  final VoidCallback onLeave;
  final VoidCallback onGranted;

  @override
  ConsumerState<_RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<_RestScreen> {
  bool _parent = false;
  String _pin = '';
  String? _error;
  bool _ok = false;

  String get _say => widget.reason == RestReason.limit
      ? 'يلا نرتاح يا ${widget.name}! خلصنا وقت اللعب النهارده، ونكمل بكرة بإذن الله'
      : 'يلا نرتاح يا ${widget.name}! نكمل اللعب في وقت تاني بإذن الله';

  @override
  void initState() {
    super.initState();
    if (widget.speak) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final v = ref.read(voiceServiceProvider);
        await v.stop();
        widget.onSpoken();
        await v.sayAndWait(_say, max: const Duration(seconds: 10));
      });
    }
  }

  Future<void> _verify() async {
    final repo = ref.read(settingsRepositoryProvider);
    final hasPin = await repo.hasPin();
    final ok = !hasPin || await repo.verifyPin(_pin);
    if (!mounted) return;
    setState(() {
      _ok = ok;
      _error = ok ? null : 'الرمز غير صحيح';
      _pin = '';
    });
  }

  Future<void> _grant({required bool restOfDay}) async {
    final repo = ref.read(settingsRepositoryProvider);
    final day = dayKey(DateTime.now());
    if (restOfDay) {
      await repo.overrideToday(day);
    } else {
      await repo.grantExtraMinutes(day, 15);
    }
    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B3A67), Color(0xFF6A5ACD), Color(0xFFB9A5F5)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ArtImage(Art.lamaaCalm, height: 170),
                const SizedBox(height: 12),
                OutlineText('يلا نرتاح يا ${widget.name}', size: 38, stroke: const Color(0xFF2B3A67)),
                const SizedBox(height: 10),
                ParchmentCard(
                  child: Text(
                    widget.reason == RestReason.limit ? 'خلصنا وقت اللعب النهارده 🌙\nنكمل بكرة بإذن الله' : 'دلوقتي مش وقت اللعب 🌙\nنكمل في وقت تاني بإذن الله',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, height: 1.5),
                  ),
                ),
                const SizedBox(height: 22),
                SunButton(label: 'تمام', onTap: widget.onLeave),
                const SizedBox(height: 18),
                if (!_parent)
                  TextButton(
                    onPressed: () => setState(() => _parent = true),
                    child: const Text('لولي الأمر', style: TextStyle(color: Colors.white, fontSize: 16)),
                  )
                else
                  _ParentPanel(
                    ok: _ok,
                    error: _error,
                    pin: _pin,
                    onDigit: (d) {
                      setState(() => _pin += d);
                      if (_pin.length == 4) _verify();
                    },
                    onClear: () => setState(() => _pin = ''),
                    onExtra: () => _grant(restOfDay: false),
                    onRestOfDay: () => _grant(restOfDay: true),
                    showExtra: widget.reason == RestReason.limit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentPanel extends ConsumerWidget {
  const _ParentPanel({required this.ok, required this.error, required this.pin, required this.onDigit, required this.onClear, required this.onExtra, required this.onRestOfDay, required this.showExtra});

  final bool ok;
  final String? error;
  final String pin;
  final void Function(String) onDigit;
  final VoidCallback onClear;
  final VoidCallback onExtra;
  final VoidCallback onRestOfDay;
  final bool showExtra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPin = ref.watch(_hasPinProvider).valueOrNull ?? true;
    if (ok || !hasPin) {
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (showExtra) FilledButton(onPressed: onExtra, child: const Text('+ 15 دقيقة')),
          FilledButton(onPressed: onRestOfDay, child: const Text('السماح لباقي اليوم')),
        ],
      );
    }
    return Column(
      children: [
        Text(error ?? 'اكتبي رمز PIN', style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 6),
        Text('●' * pin.length + '○' * (4 - pin.length), style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 6)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              SizedBox(width: 56, height: 46, child: FilledButton(onPressed: () => onDigit(d), style: FilledButton.styleFrom(padding: EdgeInsets.zero), child: Text(d, style: const TextStyle(fontSize: 20)))),
            SizedBox(width: 56, height: 46, child: OutlinedButton(onPressed: onClear, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.white), child: const Icon(Icons.backspace_outlined))),
          ],
        ),
      ],
    );
  }
}

final _hasPinProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(settingsRepositoryProvider).hasPin());
