import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:nourfadaa/domain/time_guard.dart';
import 'package:nourfadaa/features/games/game_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final settings = SettingsRepository();

  setUpAll(() {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('nourfadaa_settings_');
    databaseFactoryFfi.setDatabasesPath(dir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => AppDatabase.instance.resetForTest());

  test('voice settings default to a gentle 1s pause and persist', () async {
    final d = await settings.voiceSettings();
    expect([d.pauseMs, d.rate, d.autoRead], [1000, 0.45, true]);
    await settings.saveVoiceSettings(const VoiceSettings(pauseMs: 2000, rate: 0.35, voiceVolume: 0.6, effectsVolume: 0.4, autoRead: false));
    final s = await settings.voiceSettings();
    expect([s.pauseMs, s.rate, s.voiceVolume, s.effectsVolume, s.autoRead], [2000, 0.35, 0.6, 0.4, false]);
  });

  test('time settings, extra minutes and the day override persist', () async {
    expect((await settings.timeSettings()).dailyLimitMin, 0);
    await settings.saveTimeSettings(const TimeSettings(dailyLimitMin: 30, quietFromMin: 1200, quietToMin: 420, breakEveryMin: 20));
    final t = await settings.timeSettings();
    expect([t.dailyLimitMin, t.quietFromMin, t.quietToMin, t.breakEveryMin, t.hasQuietHours], [30, 1200, 420, 20, true]);
    await settings.grantExtraMinutes('2026-11-20', 15);
    await settings.grantExtraMinutes('2026-11-20', 15);
    expect(await settings.extraMinutes('2026-11-20'), 30);
    expect(await settings.extraMinutes('2026-11-21'), 0);
    expect(await settings.overriddenToday('2026-11-20'), isFalse);
    await settings.overrideToday('2026-11-20');
    expect(await settings.overriddenToday('2026-11-20'), isTrue);
    expect(await settings.overriddenToday('2026-11-21'), isFalse);
  });

  test('games, pack mode, motion and font size have safe defaults', () async {
    expect(await settings.gamesEnabled(), isTrue);
    expect(await settings.packMode(), 'auto');
    expect(await settings.reduceMotion(), isFalse);
    expect(await settings.fontScale(), 1.0);
    await settings.setGamesEnabled(false);
    await settings.setPackMode('off');
    await settings.setReduceMotion(true);
    await settings.setFontScale(1.2);
    expect([await settings.gamesEnabled(), await settings.packMode(), await settings.reduceMotion(), await settings.fontScale()], [false, 'off', true, 1.2]);
  });

  group('rest time', () {
    final noon = DateTime(2026, 11, 20, 12);
    test('no limit and no quiet hours means never rest', () {
      expect(checkRest(settings: const TimeSettings(), usedSeconds: 99999, now: noon), isNull);
    });

    test('daily limit: rest only after the minutes are used, extra minutes add time', () {
      const s = TimeSettings(dailyLimitMin: 30);
      expect(checkRest(settings: s, usedSeconds: 29 * 60, now: noon), isNull);
      expect(checkRest(settings: s, usedSeconds: 30 * 60, now: noon), RestReason.limit);
      expect(checkRest(settings: s, usedSeconds: 30 * 60, now: noon, extraMin: 15), isNull);
      expect(checkRest(settings: s, usedSeconds: 46 * 60, now: noon, extraMin: 15), RestReason.limit);
    });

    test('quiet hours wrap past midnight', () {
      const s = TimeSettings(quietFromMin: 20 * 60, quietToMin: 7 * 60);
      expect(checkRest(settings: s, usedSeconds: 0, now: DateTime(2026, 11, 20, 21)), RestReason.hours);
      expect(checkRest(settings: s, usedSeconds: 0, now: DateTime(2026, 11, 20, 3)), RestReason.hours);
      expect(checkRest(settings: s, usedSeconds: 0, now: DateTime(2026, 11, 20, 7)), isNull);
      expect(checkRest(settings: s, usedSeconds: 0, now: DateTime(2026, 11, 20, 19, 59)), isNull);
    });

    test('a parent override for the day lifts everything', () {
      const s = TimeSettings(dailyLimitMin: 15, quietFromMin: 0, quietToMin: 1439);
      expect(checkRest(settings: s, usedSeconds: 99999, now: noon, overriddenToday: true), isNull);
    });
  });

  test('game progress keeps the best stars, counts plays and adds only new stars to the child', () async {
    final repo = GameRepository();
    final a = await repo.saveRound(childId: 1, gameId: 'g', levelKey: 'easy', stars: 3);
    expect([a.previousBest, a.newBest, a.addedStars], [0, 3, 3]);
    final b = await repo.saveRound(childId: 1, gameId: 'g', levelKey: 'easy', stars: 2);
    expect([b.previousBest, b.newBest, b.addedStars], [3, 3, 0]);
    final c = await repo.saveRound(childId: 1, gameId: 'g', levelKey: 'easy', stars: 5);
    expect(c.addedStars, 2);
    expect((await repo.progress(1))['g']!['easy'], 5);
    expect(await repo.totalPlays(1), 3);
    expect(await repo.totalPlays(2), 0);
  });
}
