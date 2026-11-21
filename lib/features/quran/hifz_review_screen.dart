import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/cheers.dart';
import '../../core/audio/sound_service.dart';
import '../../core/design/art.dart';
import '../../core/design/joy.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/content/quran.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import 'hifz_review.dart';

enum ReviewMode {
  /// «رتّبي الآيات»: تضغط الآيات بترتيبها.
  order,

  /// «أكملي الآية»: تسمع آية وتختار التي بعدها.
  next,
}

/// ألعاب مراجعة المحفوظ: جولات من سور البنت المحفوظة فقط.
/// الآيات بصوت الشيخ دائمًا؛ الصوت الآلي للتعليمات والمديح فقط. لا «خطأ» ولا خصم.
class HifzReviewScreen extends ConsumerStatefulWidget {
  const HifzReviewScreen({super.key, required this.child, required this.content, required this.memorized, required this.mode});

  final Child child;
  final QuranContent content;
  final Set<int> memorized;
  final ReviewMode mode;

  static const int rounds = 5;

  @override
  ConsumerState<HifzReviewScreen> createState() => _HifzReviewScreenState();
}

class _HifzReviewScreenState extends ConsumerState<HifzReviewScreen> {
  late final HifzReview _review = HifzReview(widget.content, widget.memorized);
  late final _voice = ref.read(voiceServiceProvider);
  late final _player = ref.read(ayahPlayerProvider);

  int _round = 0;
  bool _finished = false;
  bool _joy = false;

  // رتّبي
  OrderRound? _order;
  final List<AyahRef> _placed = [];
  AyahRef? _nudge;

  // أكملي
  NextRound? _next;
  int? _picked;
  final Set<int> _tried = {};

  @override
  void initState() {
    super.initState();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro());
  }

  @override
  void dispose() {
    unawaited(_player.stop());
    unawaited(_voice.stop());
    super.dispose();
  }

  Future<void> _intro() async {
    if (!mounted) return;
    if (widget.mode == ReviewMode.order) {
      await _voice.sayAndWait('رتّبي الآيات: اضغطي على الآية الأولى ثم التي بعدها', max: const Duration(seconds: 8));
    } else {
      await _voice.sayAndWait('اسمعي الآية، وبعدين اختاري الآية التي بعدها', max: const Duration(seconds: 8));
      await _playHeard();
    }
  }

  void _newRound() {
    _placed.clear();
    _tried.clear();
    _picked = null;
    _nudge = null;
    if (widget.mode == ReviewMode.order) {
      _order = _review.order();
    } else {
      _next = _review.next();
    }
  }

  Future<void> _playHeard() async {
    final n = _next;
    if (n == null || !mounted) return;
    await _player.playRange(n.heard.surah, n.heard.ayah, n.heard.ayah);
  }

  Future<void> _hear(AyahRef a) async {
    await _voice.stop();
    await _player.playRange(a.surah, a.ayah, a.ayah);
  }

  Future<void> _tapOrder(AyahRef a) async {
    final o = _order;
    if (o == null || _placed.contains(a)) return;
    if (o.correct[_placed.length] == a) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() {
        _placed.add(a);
        _nudge = null;
      });
      unawaited(_hear(a));
      if (_placed.length == o.correct.length) await _roundDone();
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _nudge = a);
      await _voice.sayAndWait(Cheers.forTryAgain(widget.child.name));
    }
  }

  Future<void> _pickNext(int i) async {
    final n = _next;
    if (n == null || _picked != null || _tried.contains(i)) return;
    if (i == n.answer) {
      HapticFeedback.lightImpact();
      ref.read(soundServiceProvider).play(SoundEffect.correct);
      setState(() => _picked = i);
      await _hear(n.options[i]);
      await _roundDone();
    } else {
      ref.read(soundServiceProvider).play(SoundEffect.tap);
      setState(() => _tried.add(i));
      await _voice.sayAndWait(Cheers.forTryAgain(widget.child.name));
    }
  }

  Future<void> _roundDone() async {
    if (!mounted) return;
    await _voice.sayAndWait(Cheers.forPraise(widget.child.name));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (_round + 1 >= HifzReviewScreen.rounds) {
      setState(() {
        _finished = true;
        _joy = true;
      });
      ref.read(soundServiceProvider).play(SoundEffect.joy);
      unawaited(_voice.speak('أحسنتِ! راجعتِ محفوظك'));
      Future<void>.delayed(JoyBurst.duration, () {
        if (mounted) setState(() => _joy = false);
      });
      return;
    }
    setState(() {
      _round++;
      _newRound();
    });
    if (widget.mode == ReviewMode.next) await _playHeard();
  }

  @override
  Widget build(BuildContext context) {
    final still = ref.watch(reduceMotionProvider).valueOrNull ?? false;
    return Stack(fit: StackFit.expand, children: [
      KidScaffold(
        title: widget.mode == ReviewMode.order ? 'رتّبي الآيات' : 'أكملي الآية',
        background: Art.bgCastle,
        veil: 0.2,
        onBack: () => Navigator.of(context).maybePop(),
        body: _finished ? _done() : _body(),
      ),
      if (_joy) IgnorePointer(child: JoyBurst(level: JoyLevel.big, calm: true, reduceMotion: still)),
    ]);
  }

  Widget _progress() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: StarRow(filled: _round, total: HifzReviewScreen.rounds, size: 28),
      );

  Widget _done() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StarRow(filled: HifzReviewScreen.rounds, total: HifzReviewScreen.rounds, size: 40),
          const SizedBox(height: 12),
          const Mascot(size: 150, mood: MascotMood.cheer),
          const SizedBox(height: 12),
          OutlineText('أحسنتِ يا ${widget.child.name}!', size: 32, maxLines: 1),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PicButton(Art.icRepeat, size: 84, label: 'مرة كمان', onTap: () {
              setState(() {
                _round = 0;
                _finished = false;
                _newRound();
              });
              unawaited(_intro());
            }),
            const SizedBox(width: 24),
            PicButton(Art.icDone, size: 84, label: 'تم', onTap: () => Navigator.of(context).maybePop()),
          ]),
        ],
      ),
    );
  }

  Widget _body() {
    if (widget.mode == ReviewMode.order) {
      final o = _order;
      if (o == null) return const Center(child: Text('لا يوجد محفوظ للمراجعة بعد'));
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _progress(),
          OutlineText('سورة ${o.surahName}', size: 26, maxLines: 1),
          const SizedBox(height: 10),
          for (var i = 0; i < o.correct.length; i++)
            _Slot(index: i, ayah: i < _placed.length ? _placed[i] : null),
          const SizedBox(height: 14),
          for (final a in o.shuffled)
            if (!_placed.contains(a))
              _AyahCard(
                ayah: a,
                nudge: identical(_nudge, a),
                onTap: () => _tapOrder(a),
                onHear: () => _hear(a),
              ),
        ],
      );
    }
    final n = _next;
    if (n == null) return const Center(child: Text('لا يوجد محفوظ للمراجعة بعد'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _progress(),
        OutlineText('سورة ${n.surahName}', size: 26, maxLines: 1),
        const SizedBox(height: 10),
        ParchmentCard(
          child: Row(children: [
            PicButton(Art.icSound, size: 64, label: 'اسمعي الآية', pulse: _picked == null, onTap: _playHeard),
            const SizedBox(width: 8),
            Expanded(child: Text(n.heard.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, height: 1.8, fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 8),
        const Center(child: Icon(Icons.arrow_downward_rounded, size: 40, color: Colors.white)),
        const SizedBox(height: 8),
        for (var i = 0; i < n.options.length; i++)
          _AyahCard(
            ayah: n.options[i],
            done: _picked == i,
            faded: _tried.contains(i),
            onTap: () => _pickNext(i),
            onHear: () => _hear(n.options[i]),
          ),
      ],
    );
  }
}

/// مكان آية في الترتيب (فاضي أو اتملى).
class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.ayah});

  final int index;
  final AyahRef? ayah;

  @override
  Widget build(BuildContext context) {
    final a = ayah;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        color: a == null ? Colors.white.withValues(alpha: 0.55) : const Color(0xFFE5F7DF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: a == null ? Colors.white : const Color(0xFF7ED36B), width: 3),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: a == null ? Colors.white : const Color(0xFF7ED36B),
          child: Text('${index + 1}', style: AppText.display(18, color: a == null ? Wood.text : Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(child: a == null ? const SizedBox.shrink() : Text(a.text, style: const TextStyle(fontSize: 20, height: 1.8, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

/// آية يمكن الضغط عليها، وبجانبها زر سماعة لتسمعها بصوت الشيخ.
class _AyahCard extends StatelessWidget {
  const _AyahCard({required this.ayah, required this.onTap, required this.onHear, this.nudge = false, this.done = false, this.faded = false});

  final AyahRef ayah;
  final VoidCallback onTap;
  final VoidCallback onHear;
  final bool nudge;
  final bool done;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: faded ? 0.45 : 1,
        child: PopTap(
          onTap: faded ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
            decoration: BoxDecoration(
              color: done ? const Color(0xFFE5F7DF) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: done ? const Color(0xFF7ED36B) : (nudge ? const Color(0xFFFFC56B) : Colors.white),
                width: 4,
              ),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Row(children: [
              PicButton(Art.icSound, size: 48, label: 'اسمعي', onTap: onHear),
              const SizedBox(width: 8),
              Expanded(child: Text(ayah.text, style: const TextStyle(fontSize: 22, height: 1.8, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}
