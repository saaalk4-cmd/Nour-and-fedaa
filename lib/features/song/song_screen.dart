import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/art.dart';
import '../../core/design/joy.dart';
import '../../core/design/kit.dart';
import '../../data/content/curriculum.dart';
import '../../data/providers.dart';

/// ملف «أغنية فداء ونور» داخل assets (بدون البادئة assets/).
const kSongAsset = 'audio/song/nour_fedaa_song.mp3';

/// اليوم الذي فيه مغامرة البنت الحالية (الأسبوع + اليوم)، أو 'all' لو أنهت كل شيء.
/// يتغير هذا المفتاح فقط حين تكتمل كل مغامرات اليوم (حتى لو انتقلت لأسبوع جديد).
String currentDayKey(PathWeek path) {
  for (final d in path.days) {
    if (d.nodes.any((n) => n.state == PathState.current)) return '${path.week?.week ?? 0}-${d.day}';
  }
  return 'all';
}

/// هل اكتملت مغامرة اليوم للتو؟ ([before] = null يعني أول فتح للشاشة: لا احتفال بما اكتمل قديمًا).
bool dayJustCompleted(String? before, String now) => before != null && before != now;

/// مشغّل الأغنية (واجهة لتسهيل الاختبار بلا plugin).
abstract class SongPlayer {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<void> get completed;
  Future<void> play({required double volume});
  Future<void> pause();
  Future<void> resume();
  Future<void> seekToStart();
  Future<void> dispose();
}

class AudioplayersSongPlayer implements SongPlayer {
  final AudioPlayer _p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Stream<Duration> get position => _p.onPositionChanged;

  @override
  Stream<Duration> get duration => _p.onDurationChanged;

  @override
  Stream<void> get completed => _p.onPlayerComplete;

  @override
  Future<void> play({required double volume}) => _p.play(AssetSource(kSongAsset), volume: volume);

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> resume() => _p.resume();

  @override
  Future<void> seekToStart() => _p.seek(Duration.zero);

  @override
  Future<void> dispose() => _p.dispose();
}

/// يُنشئ مشغّلًا جديدًا لكل فتح للشاشة (يُستبدل في الاختبارات).
final songPlayerFactoryProvider = Provider<SongPlayer Function()>((ref) => AudioplayersSongPlayer.new);

/// «أغنية فداء ونور»: البنت تفتحها من زر «أغنيتنا»، أو تفتح وحدها احتفالًا بعد إنهاء مغامرة اليوم.
/// تبدأ فورًا، وتقف عند الخروج أو عند ترك التطبيق. البنتان ولَمعة يرقصن معها (إلا مع «تقليل الحركة»).
class SongScreen extends ConsumerStatefulWidget {
  const SongScreen({super.key, this.celebrate = false});

  /// فُتحت احتفالًا بإنهاء مغامرة اليوم.
  final bool celebrate;

  @override
  ConsumerState<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends ConsumerState<SongScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final SongPlayer _player = ref.read(songPlayerFactoryProvider)();
  late final AnimationController _dance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _subs = <StreamSubscription<Object?>>[];

  bool _playing = false;
  bool _ended = false;
  Duration _pos = Duration.zero;
  Duration _len = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subs
      ..add(_player.position.listen((d) => mounted ? setState(() => _pos = d) : null))
      ..add(_player.duration.listen((d) => mounted ? setState(() => _len = d) : null))
      ..add(_player.completed.listen((_) {
        if (!mounted) return;
        _dance.stop();
        setState(() {
          _playing = false;
          _ended = true;
          _pos = Duration.zero;
        });
      }));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    // لا كلام فوق الأغنية.
    unawaited(ref.read(voiceServiceProvider).stop());
    var volume = 1.0;
    try {
      volume = (await ref.read(settingsRepositoryProvider).voiceSettings()).effectsVolume;
    } catch (_) {}
    if (!mounted) return;
    try {
      await _player.play(volume: volume.clamp(0.2, 1.0));
    } catch (_) {
      return; // الصوت ميزة إضافية؛ لا يكسر الشاشة.
    }
    if (!mounted) return;
    setState(() {
      _playing = true;
      _ended = false;
    });
    _dance.repeat();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        _dance.stop();
        if (mounted) setState(() => _playing = false);
      } else if (_ended) {
        await _player.seekToStart();
        await _start();
      } else {
        await _player.resume();
        _dance.repeat();
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // لو خرجت البنت من التطبيق تقف الأغنية (لا تشتغل في الخلفية).
    if (state != AppLifecycleState.resumed && _playing) unawaited(_toggle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    _dance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = ref.watch(reduceMotionProvider).valueOrNull ?? false;
    final progress = _len.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / _len.inMilliseconds).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        KidScaffold(
          title: 'أغنية فداء ونور',
          background: Art.bgSky,
          onBack: () => context.canPop() ? context.pop() : context.go('/world'),
          body: LayoutBuilder(
            builder: (context, box) {
              // البنتان ولَمعة بينهما (1 + 0.62 + 1 من عرض البنت) داخل الهوامش.
              final girl = math.min((box.maxWidth - 40) / 2.7, box.maxHeight * (widget.celebrate ? 0.4 : 0.48));
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: ConstrainedBox(
                  // المشهد في منتصف الشاشة بدل أن يلتصق بالأعلى ويترك فراغًا.
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - 28)),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.celebrate) ...[
                      const RibbonBanner(text: 'أحسنتِ! أنهيتِ مغامرة اليوم', size: 24),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: girl + 40,
                      child: AnimatedBuilder(
                        animation: _dance,
                        builder: (context, _) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Dancer(art: Art.fedaaCheer, size: girl, t: _dance.value, phase: 0, still: still || !_playing),
                            _Dancer(art: Art.lamaaCheer, size: girl * 0.62, t: _dance.value, phase: 0.33, still: still || !_playing),
                            _Dancer(art: Art.nourCheer, size: girl, t: _dance.value, phase: 0.5, still: still || !_playing),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_playing)
                      GlossyButton(
                        color: const Color(0xFFFF8FB1),
                        label: 'إيقاف مؤقت',
                        icon: Icons.pause_rounded,
                        size: 104,
                        onTap: _toggle,
                      )
                    else
                      PicButton(Art.icPlay, size: 112, label: 'تشغيل', pulse: true, onTap: _toggle),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 14,
                        backgroundColor: Colors.white70,
                        color: const Color(0xFFFFC21F),
                      ),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
        if (widget.celebrate) JoyBurst(level: JoyLevel.big, reduceMotion: still),
      ],
    );
  }
}

class _Dancer extends StatelessWidget {
  const _Dancer({required this.art, required this.size, required this.t, required this.phase, required this.still});

  final String art;
  final double size;
  final double t;
  final double phase;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final image = ArtImage(art, width: size, height: size);
    if (still) return image;
    final a = (t + phase) * math.pi * 2;
    return Transform.translate(
      offset: Offset(0, -math.sin(a).abs() * 18),
      child: Transform.rotate(angle: math.sin(a) * 0.08, child: image),
    );
  }
}
