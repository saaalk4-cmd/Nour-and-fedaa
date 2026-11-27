import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/parent_gate.dart';
import '../../data/providers.dart';
import '../../data/quran/quran_player.dart';
import '../../data/quran/quran_source.dart';
import '../../domain/arabic_digits.dart';
import '../../domain/lesson.dart';

/// خطوة سورة: النص من المصدر (يُخفى للبراعم) وتلاوة آية آية مع تمييز الآية الحالية.
class SurahStepView extends ConsumerStatefulWidget {
  const SurahStepView({
    super.key,
    required this.step,
    required this.textFree,
    required this.icon,
    required this.onDone,
    this.next,
  });

  final LessonStep step;
  final bool textFree;
  final String icon;
  final VoidCallback onDone;
  final Widget? next;

  @override
  ConsumerState<SurahStepView> createState() => _SurahStepViewState();
}

class _SurahStepViewState extends ConsumerState<SurahStepView> {
  bool _playing = false;

  /// -1 = البسملة، null = لا شيء يُتلى.
  int? _current;
  late final QuranPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(quranPlayerProvider);
  }

  @override
  void dispose() {
    _player.stop();
    super.dispose();
  }

  Future<void> _play(Surah s) async {
    if (_playing) return;
    setState(() => _playing = true);
    final hasB = s.basmala != null;
    final urls = [
      if (hasB) s.basmala!.audioUrl,
      for (final a in s.ayahs) a.audioUrl,
    ];
    await _player.playAll(
      urls,
      repeatEach: widget.step.repeatEach,
      onAyah: (i) {
        if (mounted) setState(() => _current = hasB ? i - 1 : i);
      },
    );
    if (!mounted) return;
    setState(() {
      _playing = false;
      _current = null;
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surahProvider(widget.step.surah));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📶', style: TextStyle(fontSize: 64)),
            if (!widget.textFree)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('تعذّر تحميل السورة، تأكد من الاتصال بالإنترنت',
                    textAlign: TextAlign.center),
              ),
            IconButton.filled(
              key: const Key('surah_retry'),
              iconSize: 40,
              onPressed: () => ref.invalidate(surahProvider(widget.step.surah)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      data: (s) => widget.textFree ? _toddler(s) : _withText(context, s),
    );
  }

  Widget _playButton(Surah s) => Material(
        color: _playing ? AppColors.gold : AppColors.terracotta,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('surah_play'),
          customBorder: const CircleBorder(),
          onTap: () => _play(s),
          child: SizedBox(
            width: 120,
            height: 120,
            child: Icon(_playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
                size: 72, color: Colors.white),
          ),
        ),
      );

  Widget _toddler(Surah s) => SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 96)),
              const SizedBox(height: 24),
              _playButton(s),
              const SizedBox(height: 32),
              SizedBox(height: 72, child: widget.next),
            ],
          ),
        ),
      );

  Widget _withText(BuildContext context, Surah s) {
    TextStyle ayahStyle(bool on) => TextStyle(
          fontSize: 28,
          height: 2.0,
          color: AppColors.navy,
          backgroundColor: on ? AppColors.gold.withValues(alpha: 0.35) : null,
        );
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (widget.step.repeatEach > 1)
                  Text(
                      'نردّد خلف الشيخ: كل آية ${toArabicDigits(widget.step.repeatEach)} مرات',
                      textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (s.basmala != null)
                  Text(s.basmala!.text,
                      key: const Key('basmala'),
                      textAlign: TextAlign.center,
                      style: ayahStyle(_current == -1)),
                Text.rich(
                  key: const Key('ayahs'),
                  textAlign: TextAlign.center,
                  TextSpan(children: [
                    for (var i = 0; i < s.ayahs.length; i++)
                      TextSpan(
                        text:
                            '${s.ayahs[i].text} ﴿${toArabicDigits(s.ayahs[i].numberInSurah)}﴾ ',
                        style: ayahStyle(_current == i),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('$kQuranTextAttribution\n$kQuranAudioAttribution',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.navy.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _playButton(s),
                if (widget.next != null) ...[
                  const SizedBox(width: 24),
                  SizedBox(height: 72, child: widget.next),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// خطوة حديث: النص كما نُسخ من مصدره، والراوي والمرجع، ورابط المصدر للأهل فقط.
class HadithStepView extends ConsumerWidget {
  const HadithStepView({super.key, required this.step, required this.next});

  final LessonStep step;
  final Widget next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hadithProvider(step.hadith!));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذّر تحميل الحديث')),
      data: (h) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('📜', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('عن ${h.narrator}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: Text(h.matn,
                  key: const Key('hadith_matn'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, height: 1.9, color: AppColors.navy)),
            ),
            const SizedBox(height: 12),
            Text('${h.reference}${h.grade == null ? '' : ' — ${h.grade}'}',
                key: const Key('hadith_ref'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall),
            TextButton.icon(
              key: const Key('hadith_source'),
              onPressed: () => openExternalForParent(context, ref, h.url),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('المصدر (لولي الأمر)'),
            ),
            const SizedBox(height: 16),
            Center(child: SizedBox(height: 72, child: next)),
          ],
        ),
      ),
    );
  }
}
