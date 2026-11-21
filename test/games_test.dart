import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/ayah_player.dart';
import 'package:nourfadaa/core/audio/sound_service.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/features/games/game_content.dart';
import 'package:nourfadaa/features/games/game_kit.dart';
import 'package:nourfadaa/features/games/game_play_screen.dart';
import 'package:nourfadaa/features/games/game_providers.dart';

class SilentEngine implements SpeechEngine {
  final List<String> said = [];
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> speakAndWait(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

class _NoSound implements SoundPlayer {
  @override
  Future<void> play(SoundEffect effect) async {}
}

GameKit kitFor({required bool little, required bool respectful, required SilentEngine engine}) => GameKit(
      voice: VoiceService(engine: engine, readEnabled: () async => true, writeEnabled: (_) async {}),
      ayah: AyahPlayer(),
      sound: SoundService(player: _NoSound(), readEnabled: () async => false, writeEnabled: (_) async {}),
      childName: little ? 'نور' : 'فداء',
      little: little,
      respectful: respectful,
      seed: 7,
    );

void main() {
  final catalog = GameCatalog.parse(File(GameCatalog.asset).readAsStringSync());
  final quran = File('assets/content/quran_surahs.json').readAsStringSync();

  test('a big catalog: many games across all shelves, each with both age tracks and 3 levels', () {
    expect(catalog.games.length, greaterThanOrEqualTo(15));
    final shelves = catalog.games.map((g) => g.section).toSet();
    expect(shelves, containsAll(['quran', 'prayer', 'adhkar', 'akhlaq', 'letters', 'numbers', 'colors', 'focus']));
    for (final g in catalog.games) {
      for (final t in [g.fedaa, g.nour]) {
        expect(t.levels.length, 3, reason: g.id);
        expect(t.levels.map((l) => l.key).toSet().length, 3, reason: g.id);
        for (final l in t.levels) {
          expect(l.rounds, greaterThan(0), reason: '${g.id}/${l.key}');
          for (final id in l.listParam('pool')) {
            expect(g.items.any((i) => i.id == id), isTrue, reason: '${g.id}/${l.key}: $id');
          }
          for (final id in l.listParam('groups')) {
            expect(g.groups.any((x) => x.id == id), isTrue, reason: '${g.id}/${l.key}: $id');
          }
        }
      }
    }
  });

  test('Fedaa and Nour really play differently (not a copy with a new name)', () {
    var different = 0;
    for (final g in catalog.games.where((g) => g.minAge <= 3)) {
      final f = g.fedaa, n = g.nour;
      final same = f.mode == n.mode && f.params.toString() == n.params.toString() && f.prompt == n.prompt &&
          f.levels.map((l) => l.params.toString()).join() == n.levels.map((l) => l.params.toString()).join();
      if (!same) different++;
    }
    expect(different, catalog.games.where((g) => g.minAge <= 3).length);
  });

  test('Quran game text is Tanzil verbatim, recited by the sheikh, and respectful', () {
    for (final g in catalog.games.where((g) => g.section == 'quran')) {
      expect(g.respectful, isTrue, reason: g.id);
      for (final i in g.items) {
        expect(i.recite, isNotNull, reason: '${g.id}/${i.id} must be recited, never machine-spoken');
        if (i.label.contains('ٱ')) expect(quran.contains(i.label), isTrue, reason: '${g.id}/${i.id}');
      }
    }
  });

  test('level unlock needs 60% of the previous level stars (never frustrating)', () {
    final t = catalog.byId('wudu_order')!.fedaa;
    expect(levelUnlocked(t, const {}, 0), isTrue);
    expect(levelUnlocked(t, const {}, 1), isFalse);
    expect(levelUnlocked(t, {t.levels[0].key: t.levels[0].passStars}, 1), isTrue);
  });

  test('a downloaded pack replaces or adds games without breaking the built-in ones', () {
    const pack = '{"schema":1,"games":[{"id":"extra","section":"focus","type":"find","title":"لعبة","emoji":"⭐",'
        '"items":[{"id":"a","emoji":"⭐","label":"النجمة"}],"fedaa":{"levels":[{"key":"k","title":"سهل","rounds":1}]}}]}';
    final merged = catalog.merge(GameCatalog.parse(pack));
    expect(merged.games.length, catalog.games.length + 1);
    expect(merged.byId('extra')!.nour.levels.single.key, 'k');
  });

  // كل جولة من كل مستوى في كل لعبة تُبنى وتُرسم بلا أخطاء، لفداء ولنور، على شاشة صغيرة.
  for (final little in [false, true]) {
    testWidgets('every game round renders for ${little ? 'Nour' : 'Fedaa'} on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 720) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final g in catalog.games) {
        if (!g.fitsAge(little ? 3 : 5)) continue;
        final track = little ? g.nour : g.fedaa;
        for (final lv in track.levels) {
          final engine = SilentEngine();
          final kit = kitFor(little: little, respectful: g.respectful, engine: engine);
          final f = RoundFactory(g, track, lv, kit);
          for (var r = 0; r < lv.rounds; r++) {
            await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light(),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: f.build(r, (_) {})),
              ),
            ));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull, reason: '${g.id}/${lv.key}/$r');
          }
          if (g.section == 'quran') {
            for (final s in engine.said) {
              expect(s.contains('ٱ'), isFalse, reason: '${g.id}: ayah text must never be machine-spoken');
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
