import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/ayah_player.dart';
import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/audio/cheers.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/emoji_words.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/models/lesson_completion.dart';
import '../../data/providers.dart';
import 'kid_section_screen.dart' show spokenTitle;
import 'break_reminder.dart';
import 'celebration_view.dart';
import '../../core/design/emoji_art.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// نور تسمع اسم الدرس أولًا (إلا لو أول بطاقة تقوله نفسه)، ثم أول بطاقة.
  Future<void> _start() async {
    if (!mounted || !await _voice.isEnabled()) return;
    final title = _lesson.spokenText(spokenTitle(_lesson.title), step: true);
    final first = _cards.isEmpty ? '' : (_cards.first.say ?? _cards.first.word).trim();
    final repeats = first.isNotEmpty && title != null && (title.contains(first) || first.contains(title));
    if (title != null && !repeats) await _voice.sayAndWait(title, max: const Duration(seconds: 8));
    if (mounted && _page == 0) await _listen();
  }

  @override
  void dispose() {
    _gen++;
    _voice.stop();
    _ayahPlayer.stop();
    super.dispose();
  }

  /// يشغّل صوت الشاشة الحالية: تلاوة للقرآن، وكلمة/سؤال منطوق لغير ذلك.
  Future<void> _listen({bool manual = false}) async {
    if (!mounted || _done != null) return;
    if (!await _voice.isEnabled()) return;
    if (!manual && !(await _voice.settings()).autoRead) return;
    final gen = ++_gen;
    await _voice.stop();
    await _ayahPlayer.stop();
    final surah = _lesson.surahNumber;
    if (_isCard) {
      if (surah != null) {
        await _ayahPlayer.play(surah, _page + 1);
        return;
      }
      final c = _cards[_page];
      final r = c.recite;
      if (r != null) {
        // اسم قصير أولًا (إن وُجد) ثم تلاوة الشيخ. لا نطق آلي للآية أبدًا.
        final say = c.say;
        if (say != null && say.isNotEmpty) await _voice.sayAndWait(say, max: const Duration(seconds: 12));
        if (mounted && _isCard && identical(_cards[_page], c)) {
          await _ayahPlayer.playRange(r.surah, r.ayah, r.toAyah);
        }
        return;
      }
      final text = c.say ?? c.word;
      if (text.isNotEmpty) await _voice.sayAndWait(text, max: const Duration(seconds: 12));
    } else {
      final q = _question;
      // الجملة الطويلة لا تُقطع: تنتظر حتى 12 ثانية قبل أول اختيار.
      await _voice.sayAndWait(q.say ?? q.prompt, max: const Duration(seconds: 12));
      // نور لا تقرأ: نقرأ لها كل اختيار (بوقفة بينها) لتعرف ماذا تضغط.
      for (final o in q.options) {
        if (!mounted || gen != _gen || _picked != null) return;
        final w = _wordOf(o);
        if (w.isNotEmpty) await _voice.sayAndWait(w, max: const Duration(seconds: 8));
      }
    }
  }

  /// رقم جولة القراءة: أي ضغطة أو صفحة جديدة تُلغي القراءة الجارية.
  int _gen = 0;

  Future<void> _next() async {
    if (!_isLast) {
      setState(() {
        _page++;
        _tried.clear();
        _picked = null;
      });
      unawaited(_listen());
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم نستطع حفظ التقدم، جرّبي مرة أخرى')),
      );
    }
  }

  Future<void> _pick(LessonQuestion q, int i) async {
    if (_picked != null) return;
    _gen++; // نوقف قراءة الاختيارات الجارية
    final word = _wordOf(q.options[i]);
    if (i == q.answerIndex) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() {
        _picked = i;
        if (_tried.isEmpty) _firstTryCorrect++;
      });
      if (word.isNotEmpty) await _voice.sayAndWait(word);
      if (mounted) await _voice.sayAndWait(Cheers.forPraise(widget.child.name));
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _tried.add(i));
      if (word.isNotEmpty) await _voice.sayAndWait(word);
      if (mounted) await _voice.sayAndWait(Cheers.forTryAgain(widget.child.name));
    }
  }

  /// ما يُقال للخيار: الكلام نفسه، أو اسم الصورة لو كان صورة فقط (🐘 «فيل»).
  static String _wordOf(String option) {
    final c = VoiceService.clean(option);
    return c.isNotEmpty ? c : (emojiWord(option) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return CelebrationView(
        childName: widget.child.name,
        little: true,
        calm: const {'quran', 'adhkar', 'prayer'}.contains(_lesson.category),
        completion: done,
        onContinue: () async {
          await BreakReminder.maybeShow(context, ref.read(voiceServiceProvider));
          if (context.mounted) context.pop();
        },
      );
    }
    final answered = _isCard || _picked != null;

    // نفس عالم نور (خلفية مرسومة)، وكل الزراير صور بلا كلام.
    return KidScaffold(
      background: Art.bgSky,
      leading: PicButton(Art.icHome, size: 60, label: 'إغلاق', onTap: () => context.pop()),
      bottom: Center(
        child: PicButton(
          _isLast ? Art.icDone : Art.icNext,
          size: 96,
          label: _isLast ? 'أنهيتُ' : 'التالي',
          pulse: answered && !_saving,
          onTap: answered && !_saving ? _next : null,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: Column(
          children: [
            _Dots(total: _total, current: _page),
            const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }

  Widget _cardView(ToddlerCard c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: FittedBox(child: _BigPicture(emoji: c.emoji))),
        const SizedBox(height: 14),
        if (c.word.isNotEmpty)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: OutlineText(c.word, size: 46, maxLines: 2),
          ),
        const SizedBox(height: 16),
        PicButton(Art.icSound, size: 96, label: 'اسمعي', pulse: true, onTap: () => _listen(manual: true)),
      ],
    );
  }

  Widget _questionView(LessonQuestion q) {
    final answered = _picked != null;
    final showHelp = !answered && _tried.length >= 2;
    // كل الاختيارات صور؟ تظهر شبكة مربعات كبيرة، وإلا أزرار عريضة (وتُقرأ بصوت).
    final pictures = q.options.every((o) => repeatedArt(o) != null);
    Widget option(int i) => _PictureOption(
          label: q.options[i],
          square: pictures,
          highlight: showHelp && i == q.answerIndex,
          state: _picked == i ? _OptState.correct : (_tried.contains(i) ? _OptState.tried : _OptState.neutral),
          onTap: () => _pick(q, i),
        );
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (q.emoji != null) ...[_BigPicture(emoji: q.emoji!, size: 84), const SizedBox(width: 14)],
              PicButton(
                Art.icSound,
                size: 80,
                label: 'اسمعي السؤال',
                pulse: !answered && _tried.isEmpty,
                onTap: () => _listen(manual: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pictures)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: [for (var i = 0; i < q.options.length; i++) option(i)],
            )
          else
            for (var i = 0; i < q.options.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: option(i)),
          const SizedBox(height: 6),
          // ردّ الفعل بالصورة: لمعة فرحانة، أو لمعة بتفكّر وتشجّع (بلا كلام مكتوب).
          if (answered)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ArtImage(Art.starOn, width: 54, height: 54),
                Mascot(size: 110, mood: MascotMood.cheer),
                ArtImage(Art.starOn, width: 54, height: 54),
              ],
            )
          else if (_tried.isNotEmpty)
            const Mascot(size: 100, mood: MascotMood.encourage),
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
      padding: const EdgeInsets.all(26),
      constraints: BoxConstraints(minWidth: size * 1.2 + 52, minHeight: size * 1.2 + 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(56),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Colors.white, Color(0xFFFFF1D0)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 10))],
      ),
      // «art:اسم» = صورة مرسومة من assets/art (كروت حروف نور)، وإلا إيموجي.
      child: emoji.startsWith('art:')
          ? ArtImage(emoji.substring(4), width: size * 1.2, height: size * 1.2)
          : EmojiPic(emoji, size: size),
    );
  }
}

enum _OptState { neutral, tried, correct }

class _PictureOption extends StatelessWidget {
  const _PictureOption({
    required this.label,
    required this.state,
    required this.onTap,
    required this.highlight,
    this.square = false,
  });

  final String label;
  final bool square;
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
      height: square ? null : 112,
      child: Material(
        color: bg,
        elevation: state == _OptState.neutral ? 3 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(
            color: state == _OptState.correct ? AppColors.leaf : Colors.white,
            width: 5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: state == _OptState.tried ? null : onTap,
          child: Center(
            child: repeatedArt(label) != null
                ? Padding(padding: const EdgeInsets.all(10), child: FittedBox(child: EmojiPic(label, size: square ? 80 : 64)))
                : Text(
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
