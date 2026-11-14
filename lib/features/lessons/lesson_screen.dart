import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/ayah_player.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/models/lesson_completion.dart';
import '../../data/providers.dart';
import 'celebration_view.dart';
import 'toddler_lesson_screen.dart';

class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final child = ref.watch(selectedChildProvider);

    return lessons.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          const Scaffold(body: Center(child: Text('تعذر تحميل الدرس'))),
      data: (all) {
        if (child.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final c = child.valueOrNull;
        final matches = all.where((l) => l.id == lessonId);
        if (c == null || matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('لم نجد هذا الدرس')),
          );
        }
        // محرك المحتوى حسب العمر: 3 و4 → صورة + صوت + لمس، 5 فأكثر → الدرس الكامل.
        if (ContentLevel.forAge(c.age).pictureOnly) {
          return ToddlerLessonPlayer(lesson: matches.first, child: c);
        }
        return _LessonPlayer(lesson: matches.first, child: c);
      },
    );
  }
}

class _LessonPlayer extends ConsumerStatefulWidget {
  const _LessonPlayer({required this.lesson, required this.child});

  final Lesson lesson;
  final Child child;

  @override
  ConsumerState<_LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<_LessonPlayer> {
  int _page = 0;
  int _firstTryCorrect = 0;
  final Set<int> _tried = <int>{};
  int? _picked;
  bool _saving = false;
  LessonCompletion? _done;

  late final VoiceService _voice;
  late final AyahPlayer _ayahPlayer;

  Lesson get _lesson => widget.lesson;

  /// سور القرآن: رقم السورة من المعرّف quran_surah_N (الخطوة i = الآية i+1).
  int? get _surah {
    final m = RegExp(r'^quran_surah_(\d+)$').firstMatch(_lesson.id);
    return m == null ? null : int.parse(m.group(1)!);
  }

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceServiceProvider);
    _ayahPlayer = ref.read(ayahPlayerProvider);
    // الطفلة قد تكون وحدها: نقرأ لها أول شاشة تلقائيًا.
    WidgetsBinding.instance.addPostFrameCallback((_) => _narrate());
  }

  @override
  void dispose() {
    _voice.stop();
    _ayahPlayer.stop();
    super.dispose();
  }

  /// يقرأ الشاشة الحالية بصوت عالٍ: النطق الآلي للمحتوى التعليمي فقط،
  /// وللقرآن تلاوة مسجّلة (لا نطق آلي للآيات أو الأحاديث أبدًا).
  Future<void> _narrate({bool manual = false}) async {
    if (!mounted || _done != null) return;
    if (!await _voice.isEnabled()) return;
    final surah = _surah;
    if (_isStep && surah != null) {
      final played = await _ayahPlayer.play(surah, _page + 1);
      if (!played && manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('التلاوة غير متاحة في هذه النسخة')),
        );
      }
      return;
    }
    if (!_lesson.canSpeak) return;
    if (_isStep) {
      final st = _lesson.steps[_page];
      await _voice.speak(st.say ?? st.text);
    } else {
      final q = _lesson.questions[_page - _lesson.steps.length];
      await _voice.speak(q.say ?? q.prompt);
    }
  }
  int get _total => _lesson.steps.length + _lesson.questions.length;
  bool get _isStep => _page < _lesson.steps.length;
  bool get _isLast => _page + 1 >= _total;

  Future<void> _next() async {
    if (!_isLast) {
      setState(() {
        _page++;
        _tried.clear();
        _picked = null;
      });
      _narrate();
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(gamificationRepositoryProvider).completeLesson(
                childId: widget.child.id,
                lessonId: _lesson.id,
                firstTryCorrect: _firstTryCorrect,
                totalQuestions: _lesson.questions.length,
              );
      if (!mounted) return;
      ref.invalidate(gamificationProfileProvider(widget.child.id));
      ref.invalidate(completedLessonIdsProvider(widget.child.id));
      ref.invalidate(dailyQuestsProvider(widget.child.id));
      ref.invalidate(earnedBadgesProvider(widget.child.id));
      ref.invalidate(childrenProvider);
      HapticFeedback.mediumImpact();
      ref.read(soundServiceProvider).play(
            result.leveledUp ? SoundEffect.levelUp : SoundEffect.success,
          );
      setState(() {
        _done = result;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم نستطع حفظ التقدم، جرّبي مرة أخرى')),
      );
    }
  }

  void _pick(LessonQuestion q, int index) {
    if (_picked != null) return;
    if (index == q.answerIndex) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() {
        _picked = index;
        // نحسب الإجابة الصحيحة من أول محاولة فقط (للمكافأة الإضافية).
        if (_tried.isEmpty) _firstTryCorrect++;
      });
      if (_lesson.canSpeak) _voice.speak(q.praise ?? 'أحسنتِ!');
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _tried.add(index));
      if (_lesson.canSpeak) _voice.speak('قريب جدًا! جرّبي مرة ثانية');
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return CelebrationView(
        childName: widget.child.name,
        little: widget.child.ageGroup == AgeGroup.early,
        completion: done,
        learned: _lesson.learned,
        onContinue: () => context.pop(),
      );
    }

    final little = widget.child.ageGroup == AgeGroup.early;
    final canContinue = _isStep || _picked != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson.title),
        leading: IconButton(
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'اسمعي',
            iconSize: little ? 40 : 30,
            icon: const Icon(Icons.volume_up),
            onPressed: () => _narrate(manual: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              _ProgressBar(value: (_page + 1) / _total),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_page),
                    child: _isStep
                        ? _stepView(_lesson.steps[_page], little)
                        : _questionView(
                            _lesson.questions[_page - _lesson.steps.length]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 66,
                child: ElevatedButton(
                  onPressed: canContinue && !_saving ? _next : null,
                  child: Text(_isLast ? 'أنهيتُ الدرس 🎉' : 'التالي'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepView(LessonStep s, bool little) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.emoji,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: little ? 110 : 84),
        ),
        const SizedBox(height: 24),
        Text(
          s.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: little ? 34 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _questionView(LessonQuestion q) {
    final answered = _picked != null;
    final emoji = q.emoji;
    final little = widget.child.ageGroup == AgeGroup.early;
    // للصغيرات: بعد محاولتين نُظهر الإجابة الصحيحة بنبض لطيف (مساعدة بصرية).
    final showHelp = little && !answered && _tried.length >= 2;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (emoji != null)
            Text(emoji, style: TextStyle(fontSize: little ? 88 : 64)),
          const SizedBox(height: 10),
          Text(
            q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OptionButton(
                label: q.options[i],
                little: little,
                highlight: showHelp && i == q.answerIndex,
                state: _picked == i
                    ? _OptionState.correct
                    : (_tried.contains(i)
                        ? _OptionState.tried
                        : _OptionState.neutral),
                onTap: () => _pick(q, i),
              ),
            ),
          if (_tried.isNotEmpty && !answered)
            _FeedbackBubble(
              mood: MascotMood.encourage,
              title: 'قريب جدًا ❤️',
              body: little
                  ? (showHelp ? 'اضغطي على الإجابة التي تتحرك 👆' : 'جرّبي مرة ثانية')
                  : 'جرّبي مرة ثانية. تلميح: ${q.hint}',
            ),
          if (answered)
            _FeedbackBubble(
              mood: MascotMood.cheer,
              title: 'أحسنتِ! ✨',
              body: q.praise ?? 'إجابة صحيحة',
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 14,
          backgroundColor: Colors.white,
          color: AppColors.leaf,
        ),
      ),
    );
  }
}

enum _OptionState { neutral, tried, correct }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
    required this.little,
    required this.highlight,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  /// للصغيرات (3-4 سنوات): أزرار وخط أكبر.
  final bool little;

  /// نبض لطيف يشير إلى الإجابة الصحيحة (مساعدة بصرية).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (state) {
      case _OptionState.neutral:
        bg = Colors.white;
      case _OptionState.tried:
        bg = const Color(0xFFFFE9C7); // برتقالي لطيف، وليس أحمر
      case _OptionState.correct:
        bg = const Color(0xFFCDEFC6);
    }
    final button = SizedBox(
      width: double.infinity,
      height: little ? 96 : 72,
      child: Material(
        color: bg,
        elevation: state == _OptionState.neutral ? 2 : 0,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: state == _OptionState.tried ? null : onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: little ? 32 : 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
    return highlight ? _Pulse(child: button) : button;
  }
}

/// نبض لطيف (تكبير وتصغير بسيط) لجذب الانتباه للإجابة الصحيحة.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class _FeedbackBubble extends StatelessWidget {
  const _FeedbackBubble({
    required this.mood,
    required this.title,
    required this.body,
  });

  final MascotMood mood;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Mascot(size: 64, mood: mood),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
