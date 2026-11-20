import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../home/who_learns_screen.dart';
import '../parent/parent_gate_screen.dart';
import 'intro_audio_player.dart';
import 'intro_experience.dart';

/// أقل ثانية يُحتسب عندها التخطي كمشاهدة (المشهد 6 وما بعده).
const double kIntroCountsAsSeenAfter = 30;

/// بوابة التشغيل: أول مرة يبدأ الفيلم تلقائيًا قبل أي شاشة اختيار أو خريطة،
/// وبعدها يُفتح التطبيق مباشرة على شاشة «من سيتعلم اليوم؟».
/// المشاهدة تُحفظ فقط عند الوصول للنهاية؛ لو أُغلق التطبيق أثناء الفيلم يُعاد في المرة التالية.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key});

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

enum _Phase { loading, intro, main, parentPhone }

class _LaunchGateState extends ConsumerState<LaunchGate> {
  _Phase _phase = _Phase.loading;
  bool _fromIntro = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    var seen = true; // عند أي عطل لا نعلّق التطبيق: ندخل مباشرة.
    var parent = false;
    try {
      final repo = ref.read(settingsRepositoryProvider);
      // تليفون الأهل: يفتح على المتابعة (بعد الـPIN) بلا فيلم ولا اختيار طفلة.
      parent = await repo.deviceRole() == 'parent' && await repo.familyCode() != null;
      seen = await repo.cinematicIntroSeen();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _phase = parent ? _Phase.parentPhone : (seen ? _Phase.main : _Phase.intro));
  }

  Future<void> _finish({required bool markSeen}) async {
    if (markSeen) {
      try {
        await ref.read(settingsRepositoryProvider).setCinematicIntroSeen(true);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _fromIntro = true;
      _phase = _Phase.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      // الانتقال من الفيلم إلى الواجهة تلاشٍ ناعم؛ وللمرات التالية فتح فوري.
      duration: _fromIntro ? const Duration(milliseconds: 1400) : Duration.zero,
      child: switch (_phase) {
        _Phase.loading => const ColoredBox(key: ValueKey('loading'), color: Colors.black, child: SizedBox.expand()),
        _Phase.intro => IntroExperience(
            key: const ValueKey('intro'),
            audio: AssetIntroAudio(),
            onDone: () => _finish(markSeen: true),
            onExit: (s) => _finish(markSeen: s >= kIntroCountsAsSeenAfter),
          ),
        _Phase.main => const WhoLearnsScreen(key: ValueKey('main')),
        _Phase.parentPhone => const ParentGateScreen(key: ValueKey('parentPhone'), next: '/remote'),
      },
    );
  }
}
