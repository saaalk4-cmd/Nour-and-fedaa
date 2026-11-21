import 'package:flutter/material.dart';
import '../../core/design/art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/ayah_player.dart';
import '../../core/audio/cheers.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/design/joy.dart';
import '../../core/design/kit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/ayah_index.dart';
import '../../data/content/emoji_words.dart';
import '../../data/content/lesson.dart';
import '../../data/content/line_voice.dart';
import '../../data/models/child.dart';
import '../../data/models/lesson_completion.dart';
import '../../data/providers.dart';
import 'break_reminder.dart';
import '../../domain/gamification/milestones.dart';
import '../today/today_screen.dart' show curriculumProvider;
import 'celebration_view.dart';
import 'milestone_dialog.dart';
import 'kid_section_screen.dart' show spokenTitle;
import 'toddler_lesson_screen.dart';
import '../../core/design/emoji_art.dart';

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
  // أسئلة الترتيب: كم عنصرًا وُضع في مكانه الصحيح، وكم محاولة غير صحيحة.
  int _placed = 0;
  int _slips = 0;
  // أسئلة التوصيل: العناصر الموصولة، والعنصر الأيسر المختار حاليًا.
  final Set<int> _matched = <int>{};
  int? _leftSel;
  bool _saving = false;
  LessonCompletion? _done;
  List<Milestone> _milestones = const [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _gen++;
    _voice.stop();
    _ayahPlayer.stop();
    super.dispose();
  }

  /// رقم جولة القراءة: كل صفحة جديدة تُلغي قراءة الصفحة السابقة إن لم تنتهِ.
  int _gen = 0;
  AyahIndex _ayat = AyahIndex.empty;

  static const _ordinals = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس'];

  /// عبارة ثابتة بدل نص حديث لا يُقرأ آليًا (حتى لا يبقى جزء من السؤال صامتًا).
  static const kHadithLineSay = 'تذكّري الحديث الذي سمعناه';

  /// أول ما يفتح الدرس: يُقال اسمه (إن جاز نطقه) ثم تُقرأ الشاشة الأولى.
  Future<void> _start() async {
    final gen = ++_gen;
    try {
      _ayat = await ref.read(ayahIndexProvider.future);
    } catch (_) {}
    if (!mounted || gen != _gen) return;
    final title = _lesson.spokenText(spokenTitle(_lesson.title), step: true);
    if (title != null && await _voice.isEnabled()) {
      await _voice.sayAndWait(title);
    }
    if (mounted && gen == _gen) await _narrate();
  }

  Future<void> _recite(Recitation r) => _ayahPlayer.playRange(r.surah, r.ayah, r.toAyah);

  /// نص حديث: بصوت الأهل لو سجّلوه، وإلا عبارة ثابتة. لا نطق آلي لنص الحديث أبدًا.
  Future<void> _hadithLine(String t) async {
    if (!await _voice.playRecorded(t)) await _voice.sayAndWait(kHadithLineSay);
  }

  /// يقرأ سطور النص بالترتيب: الآية بصوت الشيخ، والكلام التعليمي بالصوت (مع وقفة بين السطور)،
  /// ونص الحديث بصوت الأهل.
  Future<bool> _readLines(String text, int gen) async {
    for (final line in text.split('\n')) {
      if (!mounted || gen != _gen) return false;
      final t = line.trim();
      if (t.isEmpty) continue;
      final c = classifyLine(_lesson, t, _ayat, surah: _surah);
      switch (c.kind) {
        case LineKind.recite:
          await _recite(c.recitation!);
          await _voice.pause();
        case LineKind.speak:
          await _voice.sayAndWait(t, max: const Duration(seconds: 12));
        case LineKind.hadith:
          await _hadithLine(t);
      }
    }
    return mounted && gen == _gen;
  }

  /// يقرأ الشاشة الحالية بصوت عالٍ. كل شيء مسموع: الآيات بتلاوة الشيخ المسجّلة، ونص الحديث
  /// بصوت الأهل، والتعليمات والاختيارات بالصوت؛ بين كل جملة وقفة. لا نطق آلي لآية أو حديث أبدًا.
  /// [manual]: ضغطة 🔊 (تعمل دائمًا حتى لو القراءة التلقائية مطفأة).
  Future<void> _narrate({bool manual = false}) async {
    if (!mounted || _done != null) return;
    if (!await _voice.isEnabled()) return;
    if (!manual && !(await _voice.settings()).autoRead) return;
    final gen = ++_gen;
    await _voice.stop();
    await _ayahPlayer.stop();
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
    if (_isStep) {
      final st = _lesson.steps[_page];
      final t = _lesson.spokenText(st.text, say: st.say, step: true);
      if (t != null) {
        // شرح أو معنى: كل سطر يُقال على حدة بوقفة بينه وبين الذي بعده.
        for (final line in t.split('\n')) {
          if (!mounted || gen != _gen) return;
          if (line.trim().isEmpty) continue;
          await _voice.sayAndWait(line.trim(), max: const Duration(seconds: 12));
        }
      } else if (st.recite == null) {
        // نص حديث: صوت الأهل إن سجّلوه، وإلا عبارة ثابتة (لا نطق آلي له).
        if (!await _voice.playRecorded(st.text)) await _voice.sayAndWait('هذا كلام جميل، هيا نعرف معناه');
      }
      final r = st.recite;
      if (r != null && mounted && gen == _gen) await _recite(r);
      return;
    }
    final q = _lesson.questions[_page - _lesson.steps.length];
    final r = q.recite;
    if (r != null) {
      // «استمعي ثم اختاري»: نقرأ التعليمات ثم نشغّل التلاوة المسجّلة.
      final intro = _lesson.spokenText(q.prompt, say: q.say, step: true);
      if (intro != null) await _voice.sayAndWait(intro, max: const Duration(seconds: 8));
      if (mounted && gen == _gen) await _recite(r);
      return;
    }
    // السؤال نفسه (سطرًا سطرًا)، أو ما كُتب ليُقال بدلًا منه.
    bool ok;
    final say = q.say;
    if (say != null && say.trim().isNotEmpty) {
      await _voice.sayAndWait(say, max: const Duration(seconds: 10));
      ok = mounted && gen == _gen;
    } else {
      ok = await _readLines(q.prompt, gen);
    }
    if (!ok) return;
    if (q.isMatch) {
      // التوصيل: نقرأ الطرف الأول كله ثم الثاني.
      for (final side in [q.matchLeft, [for (final j in q.matchRightOrder) q.matchRight[j]]]) {
        for (final o in side) {
          if (!mounted || gen != _gen) return;
          await _readOption(o, gen);
        }
      }
      return;
    }
    // ثم الاختيارات واحدًا واحدًا.
    final opts = q.isOrder ? q.options : q.displayOptions;
    for (var i = 0; i < opts.length; i++) {
      if (!mounted || gen != _gen) return;
      await _readOption(opts[i], gen, index: i);
    }
  }

  /// اختيار واحد: آية → «الاختيار الأول» ثم الشيخ؛ نص حديث → صوت الأهل؛ كلام تعليمي → يُقال.
  Future<void> _readOption(String o, int gen, {int index = 0}) async {
    // صورة فقط: اسمها (🐘 «فيل»)، أو «الاختيار الأول» للصور المكررة (العدّ مهارة السؤال).
    if (VoiceService.clean(o).isEmpty) {
      await _voice.sayAndWait(emojiWord(o) ?? 'الاختيار ${_ordinals[index % _ordinals.length]}');
      return;
    }
    final c = classifyLine(_lesson, o, _ayat, surah: _surah);
    switch (c.kind) {
      case LineKind.recite:
        await _voice.sayAndWait('الاختيار ${_ordinals[index % _ordinals.length]}');
        if (mounted && gen == _gen) {
          await _recite(c.recitation!);
          await _voice.pause();
        }
      case LineKind.speak:
        await _voice.sayAndWait(o, max: const Duration(seconds: 8));
      case LineKind.hadith:
        await _voice.sayAndWait('الاختيار ${_ordinals[index % _ordinals.length]}');
        if (mounted && gen == _gen) await _hadithLine(o);
    }
  }

  /// زر 🔊 بجانب الاختيار: الآية بصوت الشيخ، والحديث بصوت الأهل، والكلام بالصوت.
  VoidCallback? _hearOption(String o) {
    if (VoiceService.clean(o).isEmpty) {
      final w = emojiWord(o);
      return w == null ? null : () => _voice.speak(w);
    }
    final c = classifyLine(_lesson, o, _ayat, surah: _surah);
    switch (c.kind) {
      case LineKind.recite:
        return () async {
          _gen++;
          await _voice.stop();
          await _recite(c.recitation!);
        };
      case LineKind.speak:
        return () => _voice.speak(o);
      case LineKind.hadith:
        return () async {
          _gen++;
          await _voice.stop();
          await _hadithLine(o);
        };
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
        _placed = 0;
        _slips = 0;
        _matched.clear();
        _leftSel = null;
      });
      _narrate();
      return;
    }
    await _finish();
  }

  /// مكافآت الأسبوع / 4 أسابيع / التخرج: تُمنح مرة واحدة ولا تُوقف الحفظ إن فشلت.
  Future<void> _awardMilestones() async {
    try {
      final repo = ref.read(gamificationRepositoryProvider);
      final cur = await ref.read(curriculumProvider.future);
      final all = await ref.read(lessonsProvider.future);
      final reached = Milestones.newlyReached(
        curriculum: cur,
        childAge: widget.child.age,
        allLessons: all,
        completed: await repo.completedLessonIds(widget.child.id),
        alreadyGranted: await repo.grantedMilestoneIds(widget.child.id),
      );
      await repo.grantMilestones(widget.child.id, [
        for (final m in reached) (id: m.id, stars: m.stars, xp: m.xp),
      ]);
      _milestones = reached;
      ref.invalidate(gamificationProfileProvider(widget.child.id));
      ref.invalidate(earnedBadgesProvider(widget.child.id));
    } catch (_) {
      // المكافآت إضافية: لا نمنع حفظ التقدم بسببها.
    }
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
      await _awardMilestones();
      if (!mounted) return;
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

  /// سؤال التوصيل: نختار عنصرًا من اليسار ثم ما يقابله من اليمين.
  void _pickMatchLeft(LessonQuestion q, int i) {
    if (_picked != null || _matched.contains(i)) return;
    setState(() => _leftSel = i);
    if (_lesson.isSpeakable(q.matchLeft[i], step: true)) _voice.speak(q.matchLeft[i]);
  }

  void _pickMatchRight(LessonQuestion q, int j) {
    final i = _leftSel;
    if (_picked != null || i == null || _matched.contains(j)) return;
    if (i == j) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() {
        _matched.add(j);
        _leftSel = null;
        if (_matched.length == q.options.length) {
          _picked = 0;
          if (_slips == 0) _firstTryCorrect++;
        }
      });
      if (_matched.length == q.options.length) {
        _celebrate(q, 'وصّلتِ كل شيء');
      }
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() {
        _slips++;
        _leftSel = null;
      });
      _encourage();
    }
  }

  /// سؤال الترتيب: [item] فهرس العنصر في الترتيب الصحيح؛ المطلوب الآن هو [_placed].
  void _pickOrder(LessonQuestion q, int item) {
    if (_picked != null || item < _placed) return;
    if (item == _placed) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      final done = _placed + 1 == q.options.length;
      setState(() {
        _placed++;
        if (done) {
          _picked = 0;
          if (_slips == 0) _firstTryCorrect++;
        }
      });
      if (done) {
        _celebrate(q, 'رتّبتِ كل شيء');
      } else if (_lesson.isSpeakable(q.options[item], step: true)) {
        _voice.speak(q.options[item]);
      }
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _slips++);
      _encourage();
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
      _celebrate(q, null);
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _tried.add(index));
      _streak = 0;
      final hint = _tried.length >= 2 ? _lesson.spokenText(q.hint, step: true) : null;
      _encourage(hint: hint);
    }
  }

  /// إجابات صحيحة متتالية من أول مرة (ثلاث = احتفال أكبر).
  int _streak = 0;

  /// تشجيع بعد الإجابة الصحيحة: عبارة متنوعة (أو الخاصة بالسؤال)، وبعد ثلاث ورا بعض «ما شاء الله».
  Future<void> _celebrate(LessonQuestion q, String? what) async {
    final perfect = _tried.isEmpty && _slips == 0;
    _streak = perfect ? _streak + 1 : 0;
    final name = widget.child.name;
    final String line;
    if (perfect && _streak > 0 && _streak % 3 == 0) {
      line = Cheers.forStreak(name);
    } else {
      final special = q.praise == null ? null : _lesson.spokenText(q.praise!, step: true);
      line = special ?? Cheers.forPraise(name);
    }
    _gen++;
    final big = perfect && _streak > 0 && _streak % 3 == 0;
    if (big) _showJoy(JoyLevel.medium, 'ما شاء الله!');
    await _voice.sayAndWait(line);
    if (what != null && mounted) await _voice.sayAndWait(what);
  }

  JoyLevel? _joy;
  String? _joyText;
  int _joyN = 0;

  /// احتفال أكبر قليلًا بعد ثلاث إجابات صحيحة ورا بعض (هادئ في القرآن والأذكار).
  void _showJoy(JoyLevel level, String text) {
    final calm = const {'quran', 'adhkar', 'prayer'}.contains(_lesson.category);
    if (!calm) ref.read(soundServiceProvider).play(SoundEffect.joy);
    setState(() {
      _joy = level;
      _joyText = calm ? null : text;
      _joyN++;
    });
    final n = _joyN;
    Future<void>.delayed(JoyBurst.duration, () {
      if (mounted && _joyN == n) setState(() => _joy = null);
    });
  }

  Future<void> _encourage({String? hint}) async {
    _gen++;
    await _voice.sayAndWait(Cheers.forTryAgain(widget.child.name));
    if (hint != null && mounted) await _voice.sayAndWait(hint);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return CelebrationView(
        childName: widget.child.name,
        little: widget.child.ageGroup == AgeGroup.early,
        completion: done,
        calm: const {'quran', 'adhkar', 'prayer'}.contains(_lesson.category),
        learned: _lesson.learned,
        onContinue: () async {
          await MilestoneDialog.show(
              context, ref.read(voiceServiceProvider), _milestones, widget.child.name);
          if (!context.mounted) return;
          await BreakReminder.maybeShow(context, ref.read(voiceServiceProvider));
          if (context.mounted) context.pop();
        },
      );
    }

    final little = widget.child.ageGroup == AgeGroup.early;
    final canContinue = _isStep || _picked != null;

    return KidScaffold(
      title: spokenTitle(_lesson.title),
      background: SectionLook.of(_lesson.category).background,
      veil: 0.35,
      leading: GlossyButton(
        color: const Color(0xFFE76F8B),
        label: 'إغلاق',
        icon: Icons.close_rounded,
        size: 56,
        onTap: () => context.pop(),
      ),
      actions: [
        GlossyButton(
          color: const Color(0xFF2A9D8F),
          label: 'اسمعي',
          icon: Icons.volume_up_rounded,
          size: little ? 64 : 56,
          onTap: () => _narrate(manual: true),
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(child: _lessonBody(canContinue, little)),
          if (_joy != null)
            Positioned.fill(
              child: JoyBurst(
                key: ValueKey(_joyN),
                level: _joy!,
                text: _joyText,
                calm: const {'quran', 'adhkar', 'prayer'}.contains(_lesson.category),
                reduceMotion: ref.watch(reduceMotionProvider).valueOrNull ?? false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _lessonBody(bool canContinue, bool little) {
    return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              AnimatedOpacity(
                opacity: canContinue && !_saving ? 1 : 0.45,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  child: SunButton(
                    label: _isLast ? 'أنهيتُ الدرس' : 'التالي',
                    height: little ? 70 : 62,
                    onTap: canContinue && !_saving ? _next : () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _stepView(LessonStep s, bool little) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Wood.cream]),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Wood.dark, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 7))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Color(0xFFFFF1D0), shape: BoxShape.circle),
                child: s.emoji.startsWith('art:')
                    ? ArtImage(s.emoji.substring(4), width: little ? 116 : 92, height: little ? 116 : 92)
                    : EmojiPic(s.emoji, size: little ? 96 : 76),
              ),
              const SizedBox(height: 22),
              Text(
                s.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: little ? 32 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionView(LessonQuestion q) {
    final answered = _picked != null;
    final emoji = q.emoji;
    final little = widget.child.ageGroup == AgeGroup.early;
    // للصغيرات: بعد محاولتين نُظهر الإجابة الصحيحة بنبض لطيف (مساعدة بصرية).
    final showHelp = little && !answered && _tried.length >= 2;
    if (q.isOrder) return _orderView(q, answered);
    if (q.isMatch) return _matchView(q, answered);
    return SingleChildScrollView(
      child: Column(
        children: [
          if (emoji != null)
            EmojiPic(emoji, size: little ? 88 : 64),
          if (q.recite != null)
            IconButton(
              tooltip: 'استمعي للتلاوة',
              iconSize: 64,
              color: AppColors.teal,
              icon: const Icon(Icons.headphones_rounded),
              onPressed: () => _ayahPlayer.playRange(q.recite!.surah, q.recite!.ayah, q.recite!.toAyah),
            ),
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
                onHear: _hearOption(q.options[i]),
              ),
            ),
          if (_tried.isNotEmpty && !answered)
            _FeedbackBubble(
              mood: MascotMood.encourage,
              title: 'قريب جدًا',
              body: little
                  ? (showHelp ? 'اضغطي على الإجابة التي تتحرك 👆' : 'جرّبي مرة ثانية')
                  : 'جرّبي مرة ثانية. تلميح: ${q.hint}',
            ),
          if (answered)
            _FeedbackBubble(
              mood: MascotMood.cheer,
              title: 'أحسنتِ!',
              body: q.praise ?? 'إجابة صحيحة',
            ),
        ],
      ),
    );
  }
}

extension _OrderUi on _LessonPlayerState {
  Widget _matchView(LessonQuestion q, bool answered) {
    final left = q.matchLeft;
    final right = q.matchRight;
    final order = q.matchRightOrder;
    Widget cell(String text, {required bool done, required bool selected, required VoidCallback? onTap}) {
      final big = text.runes.length <= 4; // إيموجي/كلمة قصيرة: خط أكبر
      return SizedBox(
        height: 84,
        child: Material(
          color: done
              ? const Color(0xFFCDEFC6)
              : (selected ? const Color(0xFFFFE9A8) : Colors.white),
          elevation: done ? 0 : 2,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: big ? 40 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (q.emoji != null) EmojiPic(q.emoji!, size: 56),
          const SizedBox(height: 8),
          Text(
            q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < left.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: cell(left[i],
                            done: _matched.contains(i),
                            selected: _leftSel == i,
                            onTap: () => _pickMatchLeft(q, i)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    for (final j in order)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: cell(right[j],
                            done: _matched.contains(j),
                            selected: false,
                            onTap: () => _pickMatchRight(q, j)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_slips > 0 && !answered)
            const _FeedbackBubble(
              mood: MascotMood.encourage,
              title: 'قريب جدًا',
              body: 'اضغطي على صورة ثم على ما يناسبها',
            ),
          if (answered)
            _FeedbackBubble(
              mood: MascotMood.cheer,
              title: 'أحسنتِ!',
              body: q.praise ?? 'وصّلتِ كل شيء',
            ),
        ],
      ),
    );
  }

  Widget _orderView(LessonQuestion q, bool answered) {
    final shown = q.displayOptions;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (q.emoji != null) EmojiPic(q.emoji!, size: 64),
          const SizedBox(height: 10),
          Text(
            q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          // الخانات المرتّبة
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < _placed ? const Color(0xFFCDEFC6) : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  i < _placed ? '${i + 1}. ${q.options[i]}' : '${i + 1}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ),
          const SizedBox(height: 10),
          // العناصر المتبقية (بترتيب عرض مختلف)
          for (final label in shown)
            if (q.options.indexOf(label) >= _placed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OptionButton(
                  label: label,
                  little: false,
                  highlight: _slips >= 2 && q.options.indexOf(label) == _placed,
                  state: _OptionState.neutral,
                  onTap: () => _pickOrder(q, q.options.indexOf(label)),
                  onHear: _lesson.isSpeakable(label, step: true) ? () => _voice.speak(label) : null,
                ),
              ),
          if (_slips > 0 && !answered)
            const _FeedbackBubble(
              mood: MascotMood.encourage,
              title: 'قريب جدًا',
              body: 'جرّبي مرة ثانية',
            ),
          if (answered)
            _FeedbackBubble(
              mood: MascotMood.cheer,
              title: 'أحسنتِ!',
              body: q.praise ?? 'رتّبتِ كل شيء',
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
    this.onHear,
  });

  final String label;

  /// زر 🔊 لسماع الاختيار دون اختياره (null إن لم يجز نطقه).
  final VoidCallback? onHear;
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
        bg = Wood.cream;
      case _OptionState.tried:
        bg = const Color(0xFFFFE9C7); // برتقالي لطيف، وليس أحمر
      case _OptionState.correct:
        bg = const Color(0xFFCDEFC6);
    }
    final button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: little ? 96 : 72),
      child: Material(
        color: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: state == _OptionState.correct ? const Color(0xFF3F8F2F) : Wood.dark, width: 3),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: state == _OptionState.tried ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
            children: [
              if (onHear != null)
                IconButton(
                  tooltip: 'اسمعي',
                  iconSize: 32,
                  color: AppColors.teal,
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: onHear,
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: repeatedArt(label) != null
                    ? Center(child: EmojiPic(label, size: little ? 48 : 40))
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: little ? 32 : 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
              ),
              const SizedBox(width: 48),
            ],
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
    // البنت نفسها (فرحانة أو بتفكر) جنب لَمعة: الرد بالصورة قبل الكلام.
    final st = context.findAncestorStateOfType<_LessonPlayerState>();
    final cheer = mood == MascotMood.cheer;
    final c = st?.widget.child;
    final girl = c == null
        ? null
        : (c.age <= 4 ? (cheer ? Art.nourCheer : Art.nourThink) : (cheer ? Art.fedaaCheer : Art.fedaaThink));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cheer ? const Color(0xFF7ED36B) : const Color(0xFFFFC56B), width: 3),
      ),
      child: Row(
        children: [
          if (girl != null) ArtImage(girl, width: 76, height: 86),
          Mascot(size: 60, mood: mood),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  if (cheer) ...[const SizedBox(width: 4), const ArtImage(Art.starOn, width: 26, height: 26)],
                ]),
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
