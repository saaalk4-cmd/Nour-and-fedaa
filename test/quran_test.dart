import 'dart:convert';
import 'dart:io';

import 'package:buraq/data/providers.dart';
import 'package:buraq/data/quran/quran_player.dart';
import 'package:buraq/data/quran/quran_source.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:buraq/features/lesson/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Map<String, dynamic>> _fixture(int n) =>
    ((jsonDecode(File('test/fixtures/alquran_surah_$n.json').readAsStringSync())
                as Map<String, dynamic>)['data'] as List)
        .cast<Map<String, dynamic>>();

class _FakeSource implements QuranSource {
  @override
  Future<Surah> surah(int n) async =>
      parseSurah(n, _fixture(n), fatiha: n == 1 ? null : _fixture(1));
}

class _FakePlayer implements QuranPlayer {
  final played = <String>[];
  @override
  Future<void> playAll(List<String> urls,
      {int repeatEach = 1, void Function(int index)? onAyah}) async {
    for (var i = 0; i < urls.length; i++) {
      for (var r = 0; r < repeatEach; r++) {
        onAyah?.call(i);
        played.add(urls[i]);
      }
    }
  }

  @override
  Future<void> stop() async {}
}

void main() {
  cacheTests();
  group('parseSurah', () {
    test('Al-Ikhlas: basmala separated, taken from the source, 4 ayahs', () {
      final s = parseSurah(112, _fixture(112), fatiha: _fixture(1));
      final f = parseSurah(1, _fixture(1));
      expect(s.ayahs.length, 4);
      expect(s.basmala, isNotNull);
      expect(s.basmala!.text, f.ayahs.first.text);
      expect(s.ayahs.first.text.startsWith(s.basmala!.text), isFalse);
      expect(s.basmala!.audioUrl, f.ayahs.first.audioUrl);
      expect(s.ayahs.every((a) => a.audioUrl.contains('minshawi')), isTrue);
    });

    test('Al-Fatiha: no separate basmala, invisible BOM removed', () {
      final f = parseSurah(1, _fixture(1));
      expect(f.basmala, isNull);
      expect(f.ayahs.length, 7);
      expect(f.ayahs.first.text.contains('﻿'), isFalse);
    });

    test('rejects data whose ayah count does not match', () {
      final eds = _fixture(112);
      for (final e in eds) {
        (e['ayahs'] as List).removeLast();
        e['numberOfAyahs'] = 3;
      }
      expect(() => parseSurah(112, eds, fatiha: _fixture(1)),
          throwsA(isA<QuranDataException>()));
    });

    test('rejects inconsistent metadata', () {
      final eds = _fixture(112);
      eds.first['numberOfAyahs'] = 5;
      expect(() => parseSurah(112, eds, fatiha: _fixture(1)),
          throwsA(isA<QuranDataException>()));
    });
  });

  test('AlQuranCloudSource fetches once and caches; Fatiha fetched for basmala',
      () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      final n = int.parse(req.url.pathSegments[2]);
      return http.Response.bytes(
          utf8.encode(jsonEncode({'code': 200, 'data': _fixture(n)})), 200);
    });
    final src = AlQuranCloudSource(client: client);
    final s = await src.surah(112);
    await src.surah(112);
    expect(s.ayahs.length, 4);
    expect(calls.length, 2); // ١١٢ + الفاتحة للبسملة
  });

  Future<_FakePlayer> showLesson(WidgetTester t, String band) async {
    final player = _FakePlayer();
    final lesson = Lesson.fromJson({
      'id': 'q',
      'title': 'الإخلاص',
      'icon': '⭐',
      'band': band,
      'source_type': 'quran',
      'steps': [
        {'type': 'surah', 'surah': 112, 'repeat_each': 1},
        {'type': 'reward', 'stars': 3},
      ],
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LessonScreen(lessonId: 'q')),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        lessonProvider('q').overrideWith((_) async => lesson),
        quranSourceProvider.overrideWithValue(_FakeSource()),
        quranPlayerProvider.overrideWithValue(player),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    return player;
  }

  testWidgets('5-7: shows basmala and ayahs, plays basmala then each ayah, then Next',
      (t) async {
    final player = await showLesson(t, 'atfal');
    expect(find.byKey(const Key('basmala')), findsOneWidget);
    expect(find.byKey(const Key('ayahs')), findsOneWidget);
    expect(find.byKey(const Key('next_button')), findsNothing);
    await t.tap(find.byKey(const Key('surah_play')));
    await t.pumpAndSettle();
    expect(player.played.length, 5); // البسملة + ٤ آيات
    expect(find.byKey(const Key('next_button')), findsOneWidget);
  });

  testWidgets('toddlers: audio only, no Quran text on screen', (t) async {
    await showLesson(t, 'buraem');
    expect(find.byKey(const Key('basmala')), findsNothing);
    expect(find.byKey(const Key('ayahs')), findsNothing);
    expect(find.text('⭐'), findsOneWidget);
  });
}

class _MemCache implements QuranCacheStore {
  final data = <int, String>{};
  @override
  Future<String?> read(int surah) async => data[surah];
  @override
  Future<void> write(int surah, String payload) async => data[surah] = payload;
}

void cacheTests() {
  AlQuranCloudSource remoteCounting(List<String> calls, {bool fail = false}) =>
      AlQuranCloudSource(
        client: MockClient((req) async {
          if (fail) throw Exception('offline');
          calls.add(req.url.path);
          final n = int.parse(req.url.pathSegments[2]);
          return http.Response.bytes(
              utf8.encode(jsonEncode({'code': 200, 'data': _fixture(n)})), 200);
        }),
      );

  test('a surah loaded once opens later without internet', () async {
    final cache = _MemCache();
    final calls = <String>[];
    await CachingQuranSource(remote: remoteCounting(calls), cache: cache)
        .surah(112);
    expect(cache.data.keys.toSet(), {112, 1});

    // تشغيل جديد للتطبيق بلا إنترنت
    final offline = CachingQuranSource(
        remote: remoteCounting(<String>[], fail: true), cache: cache);
    final s = await offline.surah(112);
    expect(s.ayahs.length, 4);
    expect(s.basmala, isNotNull);
  });

  test('a corrupted cached copy is refetched and verified', () async {
    final cache = _MemCache();
    final bad = _fixture(112);
    (bad.first['ayahs'] as List).removeLast();
    cache.data[112] = jsonEncode(bad);
    final calls = <String>[];
    final s = await CachingQuranSource(remote: remoteCounting(calls), cache: cache)
        .surah(112);
    expect(s.ayahs.length, 4);
    expect(calls, isNotEmpty);
  });
}
