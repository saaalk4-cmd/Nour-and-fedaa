import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'cinema_painter.dart';

/// مقدمة سينمائية (نموذج أولي بصري): عالم واحد، وفداء ونور في رحلتين مختلفتين،
/// ولَمعة دليلًا بينهما. تُرسم كلها بالكود، بلا نصوص داخل المشهد وبلا شخصيات دينية.
class IntroCinemaScreen extends StatefulWidget {
  const IntroCinemaScreen({super.key});

  @override
  State<IntroCinemaScreen> createState() => _IntroCinemaScreenState();
}

class _IntroCinemaScreenState extends State<IntroCinemaScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: kCinemaSeconds.round()),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                color: Colors.white70,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: _leave,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => _c.isCompleted
                ? SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              iconSize: 34,
                              tooltip: 'إعادة',
                              icon: const Icon(Icons.replay_rounded),
                              onPressed: () => _c.forward(from: 0),
                            ),
                            const SizedBox(width: 16),
                            FilledButton(
                              onPressed: _leave,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                child: Text('هيا نبدأ ✨', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
