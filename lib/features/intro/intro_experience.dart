import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/settings_repository.dart';
import 'cinema_painter.dart';
import 'intro_audio.dart';
import 'intro_cinema_screen.dart';
import 'intro_video.dart';

/// المقدمة بمستويين:
/// 1) الأساسي: الفيلم السينمائي الحقيقي (assets/videos/cinematic_intro.mp4) بملء الشاشة، بلا أي أزرار مشغّل.
/// 2) الاحتياطي: المقدمة المرسومة بالكود [IntroCinemaScreen]، إن غاب الملف أو فشلت التهيئة أو التشغيل.
/// في الحالتين: [onDone] عند النهاية، و[onExit] عند التخطي/الرجوع (ومعها نسبة المشاهدة على جدول 45 ثانية).
class IntroExperience extends StatefulWidget {
  const IntroExperience({
    super.key,
    required this.onDone,
    required this.onExit,
    this.openVideo,
    this.audio = const IntroAudio(),
    this.holdAtEnd = const Duration(milliseconds: 600),
    this.openTimeout = const Duration(seconds: 6),
  });

  final VoidCallback onDone;
  final void Function(double seconds) onExit;

  /// للاختبار؛ الافتراضي يفتح الأصل المحلي عبر video_player.
  final IntroVideoOpener? openVideo;
  final IntroAudio audio;
  final Duration holdAtEnd;
  final Duration openTimeout;

  @override
  State<IntroExperience> createState() => _IntroExperienceState();
}

enum _Mode { opening, video, fallback }

class _IntroExperienceState extends State<IntroExperience> with WidgetsBindingObserver {
  _Mode _mode = _Mode.opening;
  IntroVideoHandle? _video;
  bool _finished = false;
  int _cueIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open();
  }

  Future<IntroVideoHandle?> _defaultOpen() async {
    var volume = 1.0;
    try {
      volume = await SettingsRepository().soundEnabled() ? 1.0 : 0.0;
    } catch (_) {}
    return VideoPlayerHandle.open(volume: volume);
  }

  Future<void> _open() async {
    IntroVideoHandle? h;
    try {
      h = await (widget.openVideo ?? _defaultOpen)().timeout(widget.openTimeout);
    } catch (_) {
      h = null;
    }
    if (!mounted) {
      await h?.dispose();
      return;
    }
    if (h == null) return _toFallback();
    _video = h;
    h.addListener(_tick);
    try {
      await h.play();
    } catch (_) {
      return _toFallback();
    }
    if (mounted && _mode == _Mode.opening) setState(() => _mode = _Mode.video);
  }

  void _tick() {
    final h = _video;
    if (h == null || _finished || _mode == _Mode.fallback) return;
    if (h.hasError) {
      _toFallback();
      return;
    }
    final total = h.duration.inMilliseconds / 1000;
    final t = cueTimeFor(h.position.inMilliseconds / 1000, total);
    while (_cueIndex < kCinemaCues.length && t >= kCinemaCues[_cueIndex].t) {
      widget.audio.onCue(kCinemaCues[_cueIndex].name);
      _cueIndex++;
    }
    if (h.ended) {
      _finished = true;
      Timer(widget.holdAtEnd, () {
        if (mounted) widget.onDone();
      });
    }
  }

  /// أي عطل يعني: المقدمة المرسومة بالكود ثم الخريطة. لا انهيار ولا شاشة سوداء عالقة.
  void _toFallback() {
    if (!mounted || _mode == _Mode.fallback) return;
    final h = _video;
    _video = null;
    h?.removeListener(_tick);
    unawaited(h?.dispose());
    setState(() => _mode = _Mode.fallback);
    unawaited(widget.audio.start());
  }

  void _exit() {
    if (_finished) return;
    _finished = true;
    final h = _video;
    final frac = h == null || h.duration == Duration.zero ? 0.0 : h.position.inMilliseconds / h.duration.inMilliseconds;
    widget.onExit(frac * kCinemaSeconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mode == _Mode.fallback) {
      if (state == AppLifecycleState.resumed) {
        unawaited(widget.audio.resume());
      } else if (state == AppLifecycleState.paused) {
        unawaited(widget.audio.pause());
      }
      return;
    }
    final h = _video;
    if (h == null || _mode != _Mode.video) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(h.play());
    } else if (state == AppLifecycleState.paused) {
      unawaited(h.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final h = _video;
    h?.removeListener(_tick);
    unawaited(h?.dispose());
    unawaited(widget.audio.stop());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _Mode.fallback) {
      return IntroCinemaScreen(onDone: widget.onDone, onExit: widget.onExit, onCue: widget.audio.onCue);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_mode == _Mode.video && _video != null) _video!.buildView(),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'تخطي',
                  iconSize: 34,
                  color: Colors.white38,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: _exit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
