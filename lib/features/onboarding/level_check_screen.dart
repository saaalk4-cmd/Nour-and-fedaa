import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/arabic_digits.dart';
import '../../domain/level_check.dart';
import 'onboarding_scaffold.dart';

final _levelCheckProvider = FutureProvider.autoDispose<LevelCheck?>((ref) async {
  final child = await ref.watch(selectedChildProvider.future);
  if (child == null) return null;
  return ref.watch(placementRepositoryProvider).checkFor(child.band());
});

/// اختبار المستوى: سؤال واحد في كل شاشة، بلا إظهار صح أو خطأ ولا درجات.
class LevelCheckScreen extends ConsumerStatefulWidget {
  const LevelCheckScreen({super.key});

  @override
  ConsumerState<LevelCheckScreen> createState() => _LevelCheckScreenState();
}

class _LevelCheckScreenState extends ConsumerState<LevelCheckScreen> {
  int _i = 0;
  final Map<int, int> _answers = {};
  bool _saving = false;

  Future<void> _finish(LevelCheck check) async {
    if (_saving) return;
    setState(() => _saving = true);
    final id = ref.read(selectedChildIdProvider);
    if (id != null) {
      await ref
          .read(placementRepositoryProvider)
          .save(id, check.placement(_answers));
    }
    if (mounted) context.go('/onboarding/ready');
  }

  void _advance(LevelCheck check) {
    if (_i + 1 >= check.questions.length) {
      _finish(check);
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_levelCheckProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _fallback(),
      data: (check) => check == null ? _fallback() : _question(check),
    );
  }

  Widget _fallback() => OnboardingScaffold(
        title: 'سنبدأ من البداية',
        child: Column(children: [
          const Spacer(),
          GoldButton(
              label: 'متابعة', onPressed: () => context.go('/onboarding/ready')),
        ]),
      );

  Widget _question(LevelCheck check) {
    final q = check.questions[_i];
    final total = check.questions.length;
    return OnboardingScaffold(
      step: '${toArabicDigits(_i + 1)} / ${toArabicDigits(total)}',
      canGoBack: false,
      title: q.text,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_i + 1) / total,
            color: AppColors.gold,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          for (var o = 0; o < q.options.length; o++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: OutlinedButton(
                  key: Key('option_$o'),
                  onPressed: _saving
                      ? null
                      : () {
                          _answers[_i] = o;
                          _advance(check);
                        },
                  child: Text(q.options[o], style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          const Spacer(),
          TextButton(
            key: const Key('skip_question'),
            onPressed: _saving ? null : () => _advance(check),
            child: const Text('لا أعرف', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
