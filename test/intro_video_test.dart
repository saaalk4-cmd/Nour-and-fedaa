import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/features/intro/cinema_painter.dart';
import 'package:nourfadaa/features/intro/intro_audio.dart';
import 'package:nourfadaa/features/intro/intro_cinema_screen.dart';
import 'package:nourfadaa/features/intro/intro_experience.dart';
import 'package:nourfadaa/features/intro/intro_video.dart';

class FakeVideo implements IntroVideoHandle {
  FakeVideo({this.failPlay = false});
  final bool failPlay;
  final _listeners = <VoidCallback>[];
  Duration _pos = Duration.zero;
  bool _ended = false;
  bool _error = false;
  bool disposed = false;
  bool playing = false;

  void advance(Duration to) {
    _pos = to;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void finish() {
    _ended = true;
    advance(duration);
  }

  void breakIt() {
    _error = true;
    advance(_pos);
  }

  @override
  Widget buildView() => const ColoredBox(key: ValueKey('fake-video'), color: Colors.indigo, child: SizedBox.expand());
  @override
  Future<void> play() async {
    if (failPlay) throw StateError('cannot play');
    playing = true;
  }

  @override
  Future<void> pause() async => playing = false;
  @override
  Duration get position => _pos;
  @override
  Duration get duration => const Duration(seconds: 45);
  @override
  bool get ended => _ended;
  @override
  bool get hasError => _error;
  @override
  void addListener(VoidCallback l) => _listeners.add(l);
  @override
  void removeListener(VoidCallback l) => _listeners.remove(l);
  @override
  Future<void> dispose() async => disposed = true;
}

class RecordingAudio extends IntroAudio {
  RecordingAudio();
  final cues = <String>[];
  @override
  void onCue(String cue) => cues.add(cue);
}

Widget host(IntroExperience w) => MaterialApp(home: w);

void main() {
  testWidgets('real video is PRIMARY: plays automatically, no controls, onDone at the end', (tester) async {
    final v = FakeVideo();
    var done = 0;
    final audio = RecordingAudio();
    await tester.pumpWidget(host(IntroExperience(
      openVideo: () async => v,
      audio: audio,
      holdAtEnd: const Duration(milliseconds: 100),
      onDone: () => done++,
      onExit: (_) => fail('no exit'),
    )));
    await tester.pump();
    expect(v.playing, isTrue);
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
    expect(find.byType(CustomPaint).evaluate().where((e) => e.widget is CustomPaint && (e.widget as CustomPaint).painter is CinemaPainter), isEmpty);
    // لا عناصر تشبه مشغّل الفيديو.
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    v.advance(const Duration(seconds: 20));
    expect(audio.cues, isNotEmpty);
    v.finish();
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, 1);
    expect(audio.cues, kCinemaCues.map((c) => c.name).toList());
  });

  testWidgets('missing video -> 2D fallback, then it still completes', (tester) async {
    var done = 0;
    await tester.pumpWidget(host(IntroExperience(
      openVideo: () async => null,
      onDone: () => done++,
      onExit: (_) => fail('no exit'),
    )));
    await tester.pump();
    expect(find.byType(IntroCinemaScreen), findsOneWidget);
    for (var i = 0; i < 48; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(done, 1);
  });

  testWidgets('default opener with no asset file present falls back without crashing', (tester) async {
    await tester.pumpWidget(host(IntroExperience(onDone: () {}, onExit: (_) {})));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.byType(IntroCinemaScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('initialization error or timeout -> fallback', (tester) async {
    await tester.pumpWidget(host(IntroExperience(
      openVideo: () async => throw StateError('init failed'),
      onDone: () {},
      onExit: (_) {},
    )));
    await tester.pump();
    expect(find.byType(IntroCinemaScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(IntroExperience(
      openVideo: () => Future<IntroVideoHandle?>.delayed(const Duration(seconds: 30)),
      openTimeout: const Duration(seconds: 1),
      onDone: () {},
      onExit: (_) {},
    )));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(IntroCinemaScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('play error and playback error both switch to the fallback and dispose the video', (tester) async {
    final bad = FakeVideo(failPlay: true);
    await tester.pumpWidget(host(IntroExperience(openVideo: () async => bad, onDone: () {}, onExit: (_) {})));
    await tester.pump();
    expect(find.byType(IntroCinemaScreen), findsOneWidget);
    expect(bad.disposed, isTrue);

    await tester.pumpWidget(const SizedBox());
    final v = FakeVideo();
    await tester.pumpWidget(host(IntroExperience(openVideo: () async => v, onDone: () {}, onExit: (_) {})));
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
    v.breakIt();
    await tester.pump();
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byType(IntroCinemaScreen), findsOneWidget);
    expect(v.disposed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back button during the real video exits once, safely, and disposes the player', (tester) async {
    final v = FakeVideo();
    final exits = <double>[];
    await tester.pumpWidget(host(IntroExperience(openVideo: () async => v, onDone: () => fail('no'), onExit: exits.add)));
    await tester.pump();
    v.advance(const Duration(seconds: 36));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits.length, 1);
    expect(exits.first, closeTo(36, 0.5));
    await tester.pumpWidget(const SizedBox());
    expect(v.disposed, isTrue);
  });

  test('cue timing scales to any video length', () {
    expect(cueTimeFor(30, 60), closeTo(22.5, 1e-9));
    expect(cueTimeFor(10, 0), 0);
  });
}
