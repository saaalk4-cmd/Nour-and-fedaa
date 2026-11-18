import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cinema_painter.dart';

/// المقدمة السينمائية: عالم واحد، وفداء ونور في رحلتين مختلفتين، ولَمعة دليلًا بينهما.
/// تُرسم بالكود (تعمل بلا إنترنت)، وتنتهي بالخريطة الكاملة ثم تستدعي [onDone] ليُكمل التطبيق.
/// لا نص داخل المشهد، ولا شخصيات دينية.
///
/// - [onDone]: وصلت المقدمة لنهايتها.
/// - [onExit]: خرج الطفل/الأهل مبكرًا (تخطٍّ أو رجوع) ومعها الثانية التي وصل إليها.
/// - [onCue]: لحظات الصوت (انظر [kCinemaCues]) لربط الموسيقى والمؤثرات لاحقًا.
class IntroCinemaScreen extends StatefulWidget {
  const IntroCinemaScreen({
    super.key,
    required this.onDone,
    required this.onExit,
    this.onCue,
    this.holdAtEnd = const Duration(milliseconds: 1500),
  });

  final VoidCallback onDone;
  final void Function(double seconds) onExit;
  final void Function(String cue)? onCue;
  final Duration holdAtEnd;

  @override
  State<IntroCinemaScreen> createState() => _IntroCinemaScreenState();
}

class _IntroCinemaScreenState extends State<IntroCinemaScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: kCinemaSeconds.round()),
  );
  bool _left = false;
  int _cueIndex = 0;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _c.addListener(_fireCues);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _hold = Timer(widget.holdAtEnd, () {
          if (mounted && !_left) {
            _left = true;
            widget.onDone();
          }
        });
      }
    });
    _c.forward();
  }

  void _fireCues() {
    final t = _c.value * kCinemaSeconds;
    while (_cueIndex < kCinemaCues.length && t >= kCinemaCues[_cueIndex].t) {
      widget.onCue?.call(kCinemaCues[_cueIndex].name);
      _cueIndex++;
    }
  }

  /// إن أُرسل التطبيق للخلفية نوقف الفيلم ونكمله عند العودة (لا قفزات ولا تعليق).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_c.isCompleted && !_left) _c.forward();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold?.cancel();
    _c.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() {
    if (_left) return;
    _left = true;
    widget.onExit(_c.value * kCinemaSeconds);
  }

  @override
  Widget build(BuildContext context) {
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
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(painter: CinemaPainter(_c.value * kCinemaSeconds)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'تخطي',
                  iconSize: 34,
                  color: Colors.white54,
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
