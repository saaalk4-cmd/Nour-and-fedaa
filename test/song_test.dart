import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:nourfadaa/features/song/song_screen.dart';
import 'package:nourfadaa/features/world/world_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Lesson _lesson(String id) => Lesson(
      id: id,
      title: id,
      emoji: '🔤',
      category: 'learn',
      minAge: 3,
      maxAge: 6,
      difficulty: 1,
      steps: const [],
      questions: const [],
      source: const ContentSource(type: 'educational', reference: 'test'),
    );

PathWeek _week(int week, List<List<PathState>> days) => PathWeek(
      week: CurriculumWeek(week: week, title: 'أسبوع', days: const []),
      finishedAll: false,
      days: [
        for (var i = 0; i < days.length; i++)
          PathDay(day: i + 1, title: 'يوم', nodes: [
            for (var j = 0; j < days[i].length; j++) PathNode(_lesson('w$week-d$i-$j'), days[i][j]),
          ]),
      ],
    );

class _FakePlayer implements SongPlayer {
  final pos = StreamController<Duration>.broadcast();
  final len = StreamController<Duration>.broadcast();
  final done = StreamController<void>.broadcast();
  final calls = <String>[];
  double? volume;

  @override
  Stream<Duration> get position => pos.stream;
  @override
  Stream<Duration> get duration => len.stream;
  @override
  Stream<void> get completed => done.stream;
  @override
  Future<void> play({required double volume}) async {
    this.volume = volume;
    calls.add('play');
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> seekToStart() async => calls.add('seek');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

class _SilentEngine implements SpeechEngine {
  int stops = 0;
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakAndWait(String text) async {}
  @override
  Future<void> stop() async => stops++;
}

class _Settings extends SettingsRepository {
  @override
  Future<VoiceSettings> voiceSettings() async => const VoiceSettings(effectsVolume: 0.7);
}

void main() {
  group('the song plays when today\'s adventure is just finished', () {
    test('first open never celebrates old days', () {
      final now = currentDayKey(_week(1, [
        [PathState.done],
        [PathState.current],
      ]));
      expect(now, '1-2');
      expect(dayJustCompleted(null, now), isFalse);
    });

    test('a lesson inside the same day is not the end of the adventure', () {
      final before = currentDayKey(_week(1, [
        [PathState.current, PathState.locked],
      ]));
      final after = currentDayKey(_week(1, [
        [PathState.done, PathState.current],
      ]));
      expect(dayJustCompleted(before, after), isFalse);
    });

    test('finishing the last lesson of the day celebrates, also across weeks and at the very end', () {
      final day1 = currentDayKey(_week(1, [
        [PathState.done, PathState.current],
        [PathState.locked],
      ]));
      final day2 = currentDayKey(_week(1, [
        [PathState.done, PathState.done],
        [PathState.current],
      ]));
      expect(dayJustCompleted(day1, day2), isTrue);
      final nextWeek = currentDayKey(_week(2, [
        [PathState.current],
      ]));
      expect(dayJustCompleted(day2, nextWeek), isTrue);
      expect(currentDayKey(const PathWeek(week: null, days: [], finishedAll: true)), 'all');
    });
  });

  group('parent settings', () {
    final settings = SettingsRepository();
    setUpAll(() {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('nourfadaa_song_');
      databaseFactoryFfi.setDatabasesPath(dir.path);
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async => AppDatabase.instance.resetForTest());

    test('the song button and the after-adventure song are on by default and can be turned off', () async {
      expect(await settings.songButton(), isTrue);
      expect(await settings.songAfterAdventure(), isTrue);
      await settings.setSongButton(false);
      await settings.setSongAfterAdventure(false);
      expect(await settings.songButton(), isFalse);
      expect(await settings.songAfterAdventure(), isFalse);
    });
  });

  for (final size in const [Size(320, 640), Size(411, 891)]) {
    testWidgets('song screen plays at once, pauses, replays, and stops on exit (${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final player = _FakePlayer();
      final engine = _SilentEngine();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          songPlayerFactoryProvider.overrideWithValue(() => player),
          settingsRepositoryProvider.overrideWithValue(_Settings()),
          voiceServiceProvider.overrideWithValue(
            VoiceService(engine: engine, readEnabled: () async => true, writeEnabled: (_) async {}),
          ),
          reduceMotionProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
          home: const SongScreen(celebrate: true),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(player.calls, ['play']);
      expect(player.volume, 0.7);
      expect(engine.stops, greaterThan(0));
      expect(find.text('أحسنتِ! أنهيتِ مغامرة اليوم'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('إيقاف مؤقت'));
      await tester.pump();
      expect(player.calls.last, 'pause');
      await tester.tap(find.bySemanticsLabel('تشغيل'));
      await tester.pump();
      expect(player.calls.last, 'resume');

      player.done.add(null);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('تشغيل'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.calls.sublist(player.calls.length - 2), ['seek', 'play']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(player.calls.last, 'dispose');
    });
  }

  testWidgets('the song banner fits on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [SongBanner(onTap: () => taps++)])),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(SongBanner));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
  });
}
