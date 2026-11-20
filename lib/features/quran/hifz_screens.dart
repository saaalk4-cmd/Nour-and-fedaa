import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/ayah_player.dart';
import '../../core/audio/voice_service.dart';
import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../data/content/quran.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/gamification/streak.dart';
import '../lessons/lesson_list_screen.dart';
import 'hifz.dart';
import 'quran_screen.dart' show quranContentProvider;

final hifzRepositoryProvider = Provider((ref) => HifzRepository(ref.watch(settingsRepositoryProvider)));

/// تقدم الحفظ للبنت المختارة.
final hifzProvider = FutureProvider.family<HifzProgress, Child>((ref, c) {
  return ref.watch(hifzRepositoryProvider).load(childId: c.id, name: c.name, age: c.age);
});

String arabicDigits(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

/// الأجزاء المتاحة لكل بنت: فداء الثلاثة، ونور عمّ وتبارك.
List<int> juzFor(Child c) => c.age >= 5 ? const [30, 29, 28] : const [30, 29];

String juzName(int j) => switch (j) { 30 => 'جزء عمّ', 29 => 'جزء تبارك', 28 => 'جزء قد سمع', _ => 'جزء $j' };

/// «قرآني»: ورد اليوم (حفظ جديد ومراجعة) ثم سور كل جزء بحالتها.
class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen> {
  int _juz = 30;

  Future<void> _open(Child c, HifzProgress p, QuranContent q, List<AyahRange> parts, HifzPurpose purpose) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SurahHifzScreen(child: c, content: q, parts: parts, purpose: purpose),
    ));
    final day = dayKey(DateTime.now());
    final repo = ref.read(hifzRepositoryProvider);
    if (purpose == HifzPurpose.newPart && result == true) {
      p.completeNew(day, q);
    } else if (purpose == HifzPurpose.review && result != null) {
      p.completeReview(day, q);
    } else if (purpose == HifzPurpose.listen && result != null && parts.isNotEmpty) {
      p.listened.add(parts.first.surah);
    } else {
      return;
    }
    await repo.save(c.id, p);
    ref.invalidate(hifzProvider(c));
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider).valueOrNull;
    final content = ref.watch(quranContentProvider);
    if (child == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final progress = ref.watch(hifzProvider(child));
    return KidScaffold(
      title: 'قرآني',
      background: Art.bgCastle,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        GlossyButton(
          color: const Color(0xFF2EC4B6),
          label: 'تدريب ممتع',
          icon: Icons.sports_esports_rounded,
          size: 56,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LessonListScreen(category: 'quran', title: 'تدريب 🎯'),
          )),
        ),
      ],
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل السور')),
        data: (q) => progress.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('تعذر تحميل الحفظ')),
          data: (p) {
            final wird = p.wirdFor(dayKey(DateTime.now()), q);
            final juzList = juzFor(child);
            if (!juzList.contains(_juz)) _juz = juzList.first;
            final surahs = [for (final s in q.surahs) if (juzOfSurah(s.surahNumber) == _juz) s]
              ..sort((a, b) => _juz == 30 ? b.surahNumber.compareTo(a.surahNumber) : a.surahNumber.compareTo(b.surahNumber));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (wird.newPart != null || wird.review.isNotEmpty)
                  _WirdCard(
                    wird: wird,
                    content: q,
                    onNew: wird.newPart == null ? null : () => _open(child, p, q, [wird.newPart!], HifzPurpose.newPart),
                    onReview: wird.review.isEmpty
                        ? null
                        : () => _open(child, p, q, [
                              for (final s in wird.review)
                                AyahRange(s, 1, q.surahs.firstWhere((x) => x.surahNumber == s).ayahs.length),
                            ], HifzPurpose.review),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final j in juzList)
                      ChoiceChip(
                        label: Text(juzName(j), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        selected: _juz == j,
                        onSelected: (_) => setState(() => _juz = j),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final s in surahs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SurahRow(
                      surah: s,
                      status: p.statusOf(s.surahNumber),
                      listened: p.listened.contains(s.surahNumber),
                      little: child.age < 5,
                      onTap: () => _open(child, p, q, [AyahRange(s.surahNumber, 1, s.ayahs.length)],
                          child.age < 5 ? HifzPurpose.listen : HifzPurpose.free),
                    ),
                  ),
                const SizedBox(height: 6),
                Text('نص القرآن: ${q.sourceName} — بصوت محمد صديق المنشاوي',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WirdCard extends StatelessWidget {
  const _WirdCard({required this.wird, required this.content, required this.onNew, required this.onReview});

  final DailyWird wird;
  final QuranContent content;
  final VoidCallback? onNew;
  final VoidCallback? onReview;

  String _name(int s) => content.surahs.firstWhere((x) => x.surahNumber == s).name;

  @override
  Widget build(BuildContext context) {
    final n = wird.newPart;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF2A9D8F), Color(0xFF4FB3BF)]),
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Column(
        children: [
          OutlineText(wird.allDone ? 'أحسنتِ! خلّصتِ ورد اليوم' : 'ورد اليوم', size: 24, stroke: const Color(0xFF14625A), maxLines: 1),
          const SizedBox(height: 8),
          if (n != null)
            _WirdTile(
              icon: '🌱',
              title: 'حفظ جديد',
              subtitle: 'سورة ${_name(n.surah)}: من ${arabicDigits(n.from)} لـ ${arabicDigits(n.to)}',
              done: wird.newDone,
              onTap: wird.newDone ? null : onNew,
            ),
          if (wird.review.isNotEmpty) ...[
            const SizedBox(height: 8),
            _WirdTile(
              icon: '🔁',
              title: 'مراجعة',
              subtitle: wird.review.map(_name).join('، '),
              done: wird.reviewDone,
              onTap: wird.reviewDone ? null : onReview,
            ),
          ],
        ],
      ),
    );
  }
}

class _WirdTile extends StatelessWidget {
  const _WirdTile({required this.icon, required this.title, required this.subtitle, required this.done, required this.onTap});

  final String icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: title,
      child: PopTap(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.display(20, color: Wood.text)),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
            ),
            Icon(done ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                color: done ? Colors.green : const Color(0xFF2A9D8F), size: 36),
          ]),
        ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah, required this.status, required this.listened, required this.little, required this.onTap});

  final Surah surah;
  final HifzStatus status;
  final bool listened;
  final bool little;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (badge, label) = little
        ? (listened ? ('⭐', 'سمعتها') : ('🎧', 'اسمعي'))
        : switch (status) {
            HifzStatus.memorized => ('✅', 'محفوظة'),
            HifzStatus.learning => ('🔁', 'بحفظها'),
            HifzStatus.fresh => ('🌱', 'جديدة'),
          };
    return WoodSign(
      icon: Text(badge),
      title: 'سورة ${surah.name}',
      subtitle: '$label · ${arabicDigits(surah.ayahs.length)} آية',
      onTap: onTap,
    );
  }
}

/// لماذا فُتحت شاشة السورة.
enum HifzPurpose { free, newPart, review, listen }

/// «اسمعي ورددي» و«سمّعي» لمقطع أو أكثر. يرجع true = «حفظتها»، false = «محتاجة أراجع»، null = خرجت.
class SurahHifzScreen extends ConsumerStatefulWidget {
  const SurahHifzScreen({super.key, required this.child, required this.content, required this.parts, required this.purpose});

  final Child child;
  final QuranContent content;
  final List<AyahRange> parts;
  final HifzPurpose purpose;

  @override
  ConsumerState<SurahHifzScreen> createState() => _SurahHifzScreenState();
}

enum _Mode { idle, listen, recite, finished }

class _SurahHifzScreenState extends ConsumerState<SurahHifzScreen> {
  _Mode _mode = _Mode.idle;
  int _repeats = 1;
  int? _surah;
  int? _ayah;
  bool _reveal = true;
  int _gen = 0;
  Completer<void>? _next;

  bool get _little => widget.child.age < 5;

  late final AyahPlayer _ayahPlayer = ref.read(ayahPlayerProvider);
  late final VoiceService _voice = ref.read(voiceServiceProvider);

  @override
  void initState() {
    super.initState();
    _ayahPlayer;
    _voice;
    if (_little) _repeats = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_little || widget.purpose == HifzPurpose.listen) {
        unawaited(_listen());
      } else {
        unawaited(_voice.speak(widget.purpose == HifzPurpose.review ? 'هيا نراجع' : 'اسمعي ورددي'));
      }
    });
  }

  @override
  void dispose() {
    _gen++;
    _next?.complete();
    unawaited(_ayahPlayer.stop());
    unawaited(_voice.stop());
    super.dispose();
  }

  Future<void> _stopAll() async {
    _gen++;
    _next?.complete();
    _next = null;
    await _ayahPlayer.stop();
    await _voice.stop();
  }

  /// يتلو الشيخ كل آية ثم سكتة بطول الآية لتردد البنت (مرة أو أكثر).
  Future<void> _listen() async {
    await _stopAll();
    final gen = _gen;
    final ayah = _ayahPlayer;
    setState(() {
      _mode = _Mode.listen;
      _reveal = !_little;
    });
    for (final part in widget.parts) {
      for (var a = part.from; a <= part.to; a++) {
        for (var r = 0; r < _repeats; r++) {
          if (!mounted || gen != _gen) return;
          setState(() {
            _surah = part.surah;
            _ayah = a;
          });
          final sw = Stopwatch()..start();
          final ok = await ayah.playRange(part.surah, a, a);
          if (!mounted || gen != _gen) return;
          if (!ok) {
            _toast('التلاوة لسه بتتنزّل، جرّبي بعد شوية');
            setState(() => _mode = _Mode.idle);
            return;
          }
          // دورها: تردد في نفس المدة تقريبًا.
          await Future<void>.delayed(sw.elapsed + const Duration(milliseconds: 700));
        }
      }
    }
    if (!mounted || gen != _gen) return;
    setState(() => _mode = _Mode.finished);
    unawaited(_voice.speak('أحسنتِ! ما شاء الله'));
  }

  /// «سمّعي»: لكل آية تقول البنت الآية بنفسها، ثم تسمع الصح إن أحبت، ثم التالية.
  Future<void> _recite() async {
    await _stopAll();
    final gen = _gen;
    setState(() => _mode = _Mode.recite);
    for (final part in widget.parts) {
      for (var a = part.from; a <= part.to; a++) {
        if (!mounted || gen != _gen) return;
        setState(() {
          _surah = part.surah;
          _ayah = a;
          _reveal = false;
        });
        await _voice.sayAndWait('دورك، سمّعي الآية');
        _next = Completer<void>();
        await _next!.future;
        _next = null;
      }
    }
    if (!mounted || gen != _gen) return;
    setState(() => _mode = _Mode.finished);
    unawaited(_voice.speak('أحسنتِ! ما شاء الله'));
  }

  Future<void> _hearCorrect() async {
    final s = _surah, a = _ayah;
    if (s == null || a == null) return;
    setState(() => _reveal = true);
    await _voice.stop();
    await _ayahPlayer.playRange(s, a, a);
  }

  void _toast(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  String _title() {
    final names = {for (final p in widget.parts) p.surah}
        .map((s) => widget.content.surahs.firstWhere((x) => x.surahNumber == s).name)
        .toList();
    return names.length == 1 ? 'سورة ${names.first}' : 'مراجعة';
  }

  @override
  Widget build(BuildContext context) {
    final cur = (_surah != null && _ayah != null)
        ? widget.content.surahs.firstWhere((x) => x.surahNumber == _surah).ayahs[_ayah! - 1]
        : null;
    return KidScaffold(
      title: _title(),
      background: Art.bgSky,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          ParchmentCard(
            child: Column(children: [
              if (cur == null)
                Text(
                  [for (final p in widget.parts) 'سورة ${widget.content.surahs.firstWhere((x) => x.surahNumber == p.surah).name}: ${arabicDigits(p.from)}–${arabicDigits(p.to)}']
                      .join('\n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                )
              else ...[
                Text('الآية ${arabicDigits(cur.number)}', style: AppText.display(22, color: Wood.text)),
                const SizedBox(height: 8),
                if (_reveal && !_little)
                  Text(cur.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, height: 1.9, fontWeight: FontWeight.w700))
                else
                  Text(_mode == _Mode.recite ? '🎤' : '🎧', style: const TextStyle(fontSize: 72)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.recite) ...[
            SunButton(label: 'اسمعي الصح', onTap: _hearCorrect),
            const SizedBox(height: 10),
            SunButton(label: 'التالي', onTap: () => _next?.complete()),
          ] else if (_mode == _Mode.finished && widget.purpose != HifzPurpose.listen && !_little) ...[
            const OutlineText('سمّعتيها؟', size: 26, maxLines: 1),
            const SizedBox(height: 10),
            SunButton(label: 'حفظتها ✅', onTap: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 10),
            SunButton(label: 'محتاجة أراجع 🔁', onTap: () => Navigator.of(context).pop(false)),
            const SizedBox(height: 10),
            _ModeButtons(onListen: _listen, onRecite: _recite),
          ] else if (_mode == _Mode.finished) ...[
            SunButton(label: 'أحسنتِ ⭐', onTap: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 10),
            SunButton(label: 'اسمعي تاني', onTap: _listen),
          ] else ...[
            if (!_little)
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
                const Text('كرّري كل آية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                for (final r in const [1, 3])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${arabicDigits(r)} ${r == 1 ? 'مرة' : 'مرات'}'),
                      selected: _repeats == r,
                      onSelected: (_) => setState(() => _repeats = r),
                    ),
                  ),
              ]),
            const SizedBox(height: 10),
            if (_mode == _Mode.listen)
              SunButton(label: 'وقفي', onTap: () async {
                await _stopAll();
                if (mounted) setState(() => _mode = _Mode.idle);
              })
            else if (_little)
              SunButton(label: 'اسمعي', onTap: _listen)
            else
              _ModeButtons(onListen: _listen, onRecite: _recite),
          ],
        ],
      ),
    );
  }
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({required this.onListen, required this.onRecite});

  final VoidCallback onListen;
  final VoidCallback onRecite;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SunButton(label: 'اسمعي ورددي 🎧', onTap: onListen),
      const SizedBox(height: 10),
      SunButton(label: 'سمّعي 🎤', onTap: onRecite),
    ]);
  }
}
