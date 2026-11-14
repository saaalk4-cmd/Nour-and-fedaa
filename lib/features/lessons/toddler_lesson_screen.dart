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

/// واجهة الصغيرات (3–4 سنوات): «صورة + صوت + كلمة قصيرة + لمس».
/// لا فقرات ولا أحاديث ولا مصادر هنا أبدًا: المصدر والنص الكامل في لوحة ولي الأمر.
class ToddlerLessonPlayer extends ConsumerStatefulWidget {
  const ToddlerLessonPlayer({super.key, required this.lesson, required this.child});

  final Lesson lesson;
  final Child child;

  @override
  ConsumerState<ToddlerLessonPlayer> createState() => _ToddlerLessonPlayerState();
}

class _ToddlerLessonPlayerState extends ConsumerState<ToddlerLessonPlayer> {
  late final List<ToddlerCard> _cards = widget.lesson.toddlerCards();
  late final List<LessonQuestion> _questions = widget.lesson.toddlerQuestions();
  late final VoiceService _voice;
  late final AyahPlayer _ayahPlayer;

  int _page = 0;
  int _firstTryCorrect = 0;
  final Set<int> _tried = <int>{};
  int? _picked;
  bool _saving = false;
  LessonCompletion? _done;

  Lesson get _lesson => widget.lesson;
  int get _total => _cards.length + _questions.length;
  bool get _isCard => _page < _cards.length;
  bool get _isLast => _page + 1 >= _total;
  LessonQuestion get _question => _questions[_page - _cards.length];

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceServiceProvider);
    _ayahPlayer = ref.read(ayahPlayerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _voice.stop();
    _ayahPlayer.stop();
    super.dispose();
  }

  /// يشغّل صوت الشاشة الحالية: تلاوة للقرآن، وكلمة/سؤال منطوق لغير ذلك.
  Future<void> _listen() async {
    if (!mounted || _done != null) return;
    if (!await _voice.isEnabled()) return;
    final surah = _lesson.surahNumber;
    if (_isCard) {
      if (surah != null) {
        await _ayahPlayer.play(surah, _page + 1);
        return;
      }
      final c = _cards[_page];
      final text = c.say ?? c.word;
      if (text.isNotEmpty) await _voice.speak(text);
    } else {
      final q = _question;
      await _voice.speak(q.say ?? q.prompt);
    }
  }

  /// الخيار الذي تضغط عليه الطفلة يُنطق (هي لا تقرأ): نحذف الرموز فقط.
  Future<void> _say(String label) => _voice.speak(label);

  Future<void> _next() async {
    if (!_isLast) {
      setState(() {
        _page++;
        _tried.clear();
        _picked = null;
      });
      _listen();
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await ref.read(gamificationRepositoryProvider).completeLesson(
            childId: widget.child.id,
            lessonId: _lesson.id,
            firstTryCorrect: _firstTryCorrect,
            totalQuestions: _questions.length,
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
      _voice.speak('أحسنتِ يا ${widget.child.name}!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم نستطع حفظ التقدم، جرّبي مرة أخرى')),
      );
    }
  }

  void _pick(LessonQuestion q, int i) {
    if (_picked != null) return;
    _say(_wordOf(q.options[i]));
    if (i == q.answerIndex) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() {
        _picked = i;
        if (_tried.isEmpty) _firstTryCorrect++;
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _voice.speak('أحسنتِ يا ${widget.child.name}!');
      });
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _tried.add(i));
    }
  }

  /// يزيل الإيموجي من نص الخيار ليُنطق الكلام فقط.
  static String _wordOf(String option) => VoiceService.clean(option);

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return CelebrationView(
        childName: widget.child.name,
        little: true,
        completion: done,
        onContinue: () => context.pop(),
      );
    }
    final answered = _isCard || _picked != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'إغلاق',
          iconSize: 34,
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: _Dots(total: _total, current: _page),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_page),
                    child: _isCard ? _cardView(_cards[_page]) : _questionView(_question),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _RoundButton(
                size: 92,
                color: answered ? AppColors.leaf : Colors.black12,
                icon: _isLast ? Icons.check_rounded : Icons.arrow_back_rounded,
                tooltip: _isLast ? 'أنهيتُ' : 'التالي',
                onTap: answered && !_saving ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardView(ToddlerCard c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BigPicture(emoji: c.emoji),
        const SizedBox(height: 18),
        if (c.word.isNotEmpty)
          Text(
            c.word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        const SizedBox(height: 22),
        _RoundButton(
          size: 96,
          color: AppColors.sun,
          icon: Icons.volume_up_rounded,
          tooltip: 'اسمعي',
          pulse: true,
          onTap: _listen,
        ),
      ],
    );
  }

  Widget _questionView(LessonQuestion q) {
    final answered = _picked != null;
    final showHelp = !answered && _tried.length >= 2;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (q.emoji != null) _BigPicture(emoji: q.emoji!, size: 96),
          const SizedBox(height: 8),
          _RoundButton(
            size: 76,
            color: AppColors.sun,
            icon: Icons.volume_up_rounded,
            tooltip: 'اسمعي السؤال',
            pulse: !answered && _tried.isEmpty,
            onTap: _listen,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PictureOption(
                label: q.options[i],
                highlight: showHelp && i == q.answerIndex,
                state: _picked == i
                    ? _OptState.correct
                    : (_tried.contains(i) ? _OptState.tried : _OptState.neutral),
                onTap: () => _pick(q, i),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 6),
            const Mascot(size: 96, mood: MascotMood.cheer),
            Text(
              'أحسنتِ يا ${widget.child.name}! 🌟',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ] else if (_tried.isNotEmpty)
            const Text(
              'جرّبي مرة ثانية 🌸',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 26 : 14,
            height: 14,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.leaf : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
      ],
    );
  }
}

class _BigPicture extends StatelessWidget {
  const _BigPicture({required this.emoji, this.size = 150});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(48),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.pulse = false,
  });

  final double size;
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final btn = Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: onTap == null ? 0 : 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.55, color: Colors.white),
          ),
        ),
      ),
    );
    return pulse ? _Pulse(child: btn) : btn;
  }
}

enum _OptState { neutral, tried, correct }

class _PictureOption extends StatelessWidget {
  const _PictureOption({
    required this.label,
    required this.state,
    required this.onTap,
    required this.highlight,
  });

  final String label;
  final _OptState state;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (state) {
      case _OptState.neutral:
        bg = Colors.white;
      case _OptState.tried:
        bg = const Color(0xFFFFE9C7);
      case _OptState.correct:
        bg = const Color(0xFFCDEFC6);
    }
    final button = SizedBox(
      width: double.infinity,
      height: 112,
      child: Material(
        color: bg,
        elevation: state == _OptState.neutral ? 3 : 0,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: state == _OptState.tried ? null : onTap,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
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

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
