import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/ayah_player.dart';
import 'package:nourfadaa/core/audio/sound_service.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/quran.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/features/quran/hifz.dart';
import 'package:nourfadaa/features/quran/hifz_review_screen.dart';

class _Silent implements SpeechEngine {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakAndWait(String text) async {}
  @override
  Future<void> stop() async {}
}

class _NoSound implements SoundPlayer {
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

class _Player extends AyahPlayer {
  final played = <String>[];
  @override
  Future<bool> playRange(int surah, int from, int to) async {
    played.add('$surah:$from');
    return true;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  final q = QuranRepository.parse(File('assets/content/quran_surahs.json').readAsStringSync());

  testWidgets('ordering memorized ayat: wrong taps are gentle, right order moves to the next round', (tester) async {
    tester.view.physicalSize = const Size(360, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final player = _Player();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        voiceServiceProvider.overrideWithValue(
            VoiceService(engine: _Silent(), readEnabled: () async => false, writeEnabled: (_) async {})),
        soundServiceProvider.overrideWithValue(
            SoundService(player: _NoSound(), readEnabled: () async => false, writeEnabled: (_) async {})),
        ayahPlayerProvider.overrideWithValue(player),
        reduceMotionProvider.overrideWith((_) async => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (ctx, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: HifzReviewScreen(
          child: const Child(id: 1, name: 'فداء', age: 5),
          content: q,
          memorized: const {112}, // الإخلاص: 4 آيات
          mode: ReviewMode.order,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final ikhlas = q.surahs.firstWhere((s) => s.surahNumber == 112);
    expect(find.text('سورة ${ikhlas.name}'), findsWidgets);
    final shown = [for (final a in ikhlas.ayahs) if (find.text(a.text).evaluate().isNotEmpty) a];
    expect(shown.length, inInclusiveRange(3, 4));
    // ضغطة على آخر آية أولًا: لا تتحرك ولا يظهر «خطأ».
    await tester.tap(find.text(shown.last.text));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('خطأ'), findsNothing);
    expect(player.played, isEmpty);
    for (final a in shown) {
      await tester.tap(find.text(a.text).last);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(player.played, [for (final a in shown) '112:${a.number}']);
    expect(tester.takeException(), isNull);
  });

  test('Fedaa can play from the start because At-Talaq to An-Nas is memorized', () {
    expect(HifzProgress.initialFor(name: 'فداء', age: 5).memorized.isNotEmpty, isTrue);
  });
}
