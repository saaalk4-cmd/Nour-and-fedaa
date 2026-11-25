import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/lesson_audio.dart';
import '../../data/providers.dart';
import '../../domain/arabic_digits.dart';
import '../../domain/badges.dart';
import '../../domain/lesson.dart';

/// شاشة الدرس: استماع ← ترديد ← مكافأة. بلا قراءة، أزرار كبيرة.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId, this.review = false});

  final String lessonId;

  /// مراجعة لدرس سبق إتمامه: لا نجوم جديدة، ويُجدول موعد المراجعة التالي.
  final bool review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: lesson.maybeWhen(
          data: (l) => l.textFreeForChild
              ? const SizedBox.shrink()
              : Text(l.subtitle == null ? l.title : '${l.title} – ${l.subtitle}'),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: lesson.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('تعذّر تحميل الدرس، حاول لاحقًا')),
        data: (l) => _LessonRunner(lesson: l, review: review),
      ),
    );
  }
}

class _LessonRunner extends ConsumerStatefulWidget {
  const _LessonRunner({required this.lesson, required this.review});

  final Lesson lesson;
  final bool review;

  @override
  ConsumerState<_LessonRunner> createState() => _LessonRunnerState();
}

class _LessonRunnerState extends ConsumerState<_LessonRunner> {
  int _index = 0;
  int _repeats = 0;
  bool _playing = false;
  bool _heard = false;
  int _earned = 0;
  List<BadgeDef> _newBadges = const [];
  bool _saved = false;

  LessonStep get _step => widget.lesson.steps[_index];

  void _next() => setState(() {
        _index++;
        _repeats = 0;
        _heard = false;
        if (_step.type == StepType.reward) _complete();
      });

  Future<void> _complete() async {
    if (_saved) return;
    _saved = true;
    final childId = ref.read(selectedChildIdProvider);
    if (childId == null) return;
    if (widget.review) {
      await ref
          .read(reviewRepositoryProvider)
          .recordReview(childId, widget.lesson.id, remembered: true);
      ref.invalidate(dueReviewProvider);
      return;
    }
    final added = await ref.read(progressRepositoryProvider).complete(
          childId: childId,
          lessonId: widget.lesson.id,
          stars: _step.stars,
        );
    final fresh = await ref.read(badgeRepositoryProvider).evaluate(childId);
    ref.invalidate(selectedChildProvider);
    ref.invalidate(dueReviewProvider);
    if (mounted) {
      setState(() {
        _earned = added;
        _newBadges = fresh;
      });
    }
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    await ref.read(lessonAudioProvider).play(widget.lesson);
    if (!mounted) return;
    setState(() {
      _playing = false;
      _heard = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step.type) {
      case StepType.listen:
        return _page(
          emoji: widget.lesson.icon ?? '🎧',
          button: _bigButton(
            key: const Key('listen_button'),
            icon: _playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
            onTap: _play,
          ),
          next: _heard ? _nextButton() : null,
        );
      case StepType.repeat:
        final times = _step.times;
        return _page(
          emoji: widget.lesson.icon ?? '🗣️',
          progress: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < times; i++)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    i < _repeats ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 40,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          button: _bigButton(
            key: const Key('repeat_button'),
            icon: Icons.mic_rounded,
            onTap: _repeats >= times ? null : () => setState(() => _repeats++),
          ),
          next: _repeats >= times ? _nextButton() : null,
        );
      case StepType.reward:
        return _page(
          emoji: '🌟',
          progress: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _step.stars; i++)
                const Icon(Icons.star_rounded, size: 64, color: AppColors.gold),
            ],
          ),
          caption: [
            _earned > 0 ? 'أحسنت! +${toArabicDigits(_earned)}' : 'أحسنت!',
            for (final b in _newBadges) '${b.emoji} ${b.title}',
          ].join('\n'),
          next: FilledButton(
            key: const Key('finish_button'),
            style: _nextStyle,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            child: const Icon(Icons.check_rounded, size: 40),
          ),
        );
    }
  }

  static final _nextStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.navy,
    foregroundColor: AppColors.cream,
    minimumSize: const Size(140, 72),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
  );

  Widget _nextButton() => FilledButton(
        key: const Key('next_button'),
        style: _nextStyle,
        onPressed: _next,
        // الاتجاه RTL: السهم للأمام يشير لليسار.
        child: const Icon(Icons.arrow_back_rounded, size: 40),
      );

  Widget _bigButton({
    required Key key,
    required IconData icon,
    required VoidCallback? onTap,
  }) =>
      Material(
        color: onTap == null ? Colors.grey.shade400 : AppColors.terracotta,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 160,
            height: 160,
            child: Icon(icon, size: 90, color: Colors.white),
          ),
        ),
      );

  Widget _page({
    required String emoji,
    Widget? button,
    Widget? progress,
    String? caption,
    Widget? next,
  }) =>
      SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 96)),
                const SizedBox(height: 24),
                if (progress != null) ...[progress, const SizedBox(height: 24)],
                if (caption != null) ...[
                  Text(caption,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                ],
                if (button != null) ...[button, const SizedBox(height: 32)],
                SizedBox(height: 72, child: next),
              ],
            ),
          ),
        ),
      );
}
