import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// مسار الفيلم السينمائي الحقيقي (أصل محلي يعمل بلا إنترنت).
const String kIntroVideoAsset = 'assets/videos/cinematic_intro.mp4';

/// واجهة صغيرة فوق مشغّل الفيديو، ليُختبر المسار الأساسي والاحتياطي دون جهاز.
abstract class IntroVideoHandle {
  /// العرض بلا أي أزرار تحكم أو شريط زمني.
  Widget buildView();
  Future<void> play();
  Future<void> pause();
  Duration get position;
  Duration get duration;
  bool get ended;
  bool get hasError;
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<void> dispose();
}

/// يفتح الفيلم: null إن لم يوجد الملف أو تعذّرت التهيئة (فيذهب التطبيق للمقدمة الاحتياطية).
typedef IntroVideoOpener = Future<IntroVideoHandle?> Function();

class VideoPlayerHandle implements IntroVideoHandle {
  VideoPlayerHandle._(this._c);

  final VideoPlayerController _c;

  static Future<IntroVideoHandle?> open({double volume = 1}) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(kIntroVideoAsset)) return null;
    } catch (_) {
      return null;
    }
    final c = VideoPlayerController.asset(
      kIntroVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      await c.setLooping(false);
      await c.setVolume(volume);
      return VideoPlayerHandle._(c);
    } catch (_) {
      await c.dispose();
      return null;
    }
  }

  @override
  Widget buildView() => Center(
        child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
      );

  @override
  Future<void> play() => _c.play();

  @override
  Future<void> pause() => _c.pause();

  @override
  Duration get position => _c.value.position;

  @override
  Duration get duration => _c.value.duration;

  @override
  bool get ended => _c.value.duration > Duration.zero && _c.value.position >= _c.value.duration && !_c.value.isPlaying;

  @override
  bool get hasError => _c.value.hasError;

  @override
  void addListener(VoidCallback listener) => _c.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _c.removeListener(listener);

  @override
  Future<void> dispose() => _c.dispose();
}
