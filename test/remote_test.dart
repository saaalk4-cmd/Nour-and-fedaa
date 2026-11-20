import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/models/child_report.dart';
import 'package:nourfadaa/data/models/gamification.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:nourfadaa/features/remote/family_code.dart';
import 'package:nourfadaa/features/remote/remote_client.dart';
import 'package:nourfadaa/features/remote/remote_controls.dart';
import 'package:nourfadaa/features/remote/remote_summary.dart';
import 'package:nourfadaa/features/remote/remote_sync.dart';
import 'package:nourfadaa/features/remote/remote_view_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Lesson _lesson(String id, {int questions = 0}) => Lesson(
      id: id,
      title: '🔤 درس $id',
      emoji: '🔤',
      category: 'learn',
      minAge: 3,
      maxAge: 6,
      difficulty: 1,
      steps: const [],
      questions: [
        for (var i = 0; i < questions; i++)
          const LessonQuestion(prompt: 'س', options: ['أ', 'ب'], answerIndex: 0, hint: ''),
      ],
      source: const ContentSource(type: 'educational', reference: 'test'),
    );

class _FakeClient implements RemoteClient {
  final puts = <String, String>{};
  RemoteDoc? doc;
  bool offline = false;
  bool fail = false;

  @override
  Future<bool> put(String code, String json) async {
    if (fail) return false;
    puts[code] = json;
    return true;
  }

  @override
  Future<RemoteDoc?> get(String code) async {
    if (offline) throw const SocketException('no net');
    return doc;
  }
}

ChildSummary _summary() => ChildSummary.build(
      report: ReportBuilder.build(
        child: const Child(id: 1, name: 'فداء', age: 5),
        profile: const GamificationProfile(xp: 0, stars: 42, level: 1, streakDays: 0, dailyQuestsCompleted: 0, totalLessons: 2),
        lessons: [_lesson('a', questions: 2), _lesson('b'), _lesson('c')],
        progress: [
          ProgressEntry(lessonId: 'a', score: 1, completedAt: DateTime(2026, 11, 19, 17)),
          ProgressEntry(lessonId: 'b', score: 0, completedAt: DateTime(2026, 11, 20, 9)),
        ],
        badgesEarned: 0,
        usageTodaySeconds: 25 * 60,
        usageTotalSeconds: 300 * 60,
        today: '2026-11-20',
      ),
      path: PathWeek(
        week: const CurriculumWeek(week: 3, title: 'أسبوع', days: []),
        finishedAll: false,
        days: [
          PathDay(day: 1, title: 'يوم', nodes: [PathNode(_lesson('a'), PathState.done)]),
          PathDay(day: 2, title: 'يوم', nodes: [PathNode(_lesson('c'), PathState.current)]),
        ],
      ),
      weekSeconds: const [0, 600, 1200, 0, 1800, 900, 1500],
      gamePlays: 7,
    );

void main() {
  group('family code', () {
    test('16 unambiguous characters, typed in any shape', () {
      final code = FamilyCode.generate(Random(1));
      expect(code.length, 16);
      expect(code.split('').every(FamilyCode.alphabet.contains), isTrue);
      final pretty = FamilyCode.pretty(code);
      expect(pretty.length, 19);
      expect(FamilyCode.normalize(pretty.toLowerCase().replaceAll('-', ' ')), code);
      expect(FamilyCode.normalize('ABC'), isNull);
      expect(FamilyCode.normalize('O0O0O0O0O0O0O0O0'), isNull, reason: 'no look-alike characters');
      expect(FamilyCode.generate(), isNot(FamilyCode.generate()));
    });
  });

  test('a child summary carries numbers only, survives the trip, and knows where she is', () {
    final s = _summary();
    expect([s.todayMin, s.totalMin, s.stars, s.lessonsDone, s.lessonsTotal, s.gamePlays], [25, 300, 42, 2, 3, 7]);
    expect([s.week, s.day, s.nextLesson], [3, 2, 'درس c']);
    expect(s.weekMin, [0, 10, 20, 0, 30, 15, 25]);
    expect(s.recent.first.title, 'درس b', reason: 'newest first, no emoji');
    expect(s.review, ['درس a'], reason: '1 of 2 right first time');
    final back = FamilySummary.decode(FamilySummary(children: [s], dailyLimitMin: 45, madeAt: DateTime(2026, 11, 20)).encode());
    final c = back.children.single;
    expect([c.name, c.age, c.todayMin, c.stars, c.week, c.day, c.nextLesson], ['فداء', 5, 25, 42, 3, 2, 'درس c']);
    expect(c.recent.map((r) => r.mastered), [true, false]);
    expect(back.dailyLimitMin, 45);
  });

  test('firestore document parsing', () {
    const body = '{"name":"x","fields":{"json":{"stringValue":"{\\"v\\":1}"},'
        '"updatedAt":{"timestampValue":"2026-11-20T10:00:00Z"},"v":{"integerValue":"1"}}}';
    final d = FirestoreRemoteClient.parse(body)!;
    expect(d.json, '{"v":1}');
    expect(d.updatedAt.toUtc(), DateTime.utc(2026, 11, 20, 10));
    expect(FirestoreRemoteClient.parse('{"name":"x"}'), isNull);
  });

  group('sync from the girls\' phone', () {
    final settings = SettingsRepository();
    setUpAll(() {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('nourfadaa_remote_');
      databaseFactoryFfi.setDatabasesPath(dir.path);
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async => AppDatabase.instance.resetForTest());

    RemoteSyncService service(_FakeClient client, {bool configured = true, DateTime Function()? now}) => RemoteSyncService(
          settings: settings,
          client: client,
          summarize: () async => FamilySummary(children: [_summary()], dailyLimitMin: 0, madeAt: DateTime(2026)),
          configured: () => configured,
          now: now,
        );

    test('nothing leaves the phone until the parent turns it on', () async {
      final client = _FakeClient();
      expect(await settings.remoteSyncOn(), isFalse);
      expect(await settings.deviceRole(), 'kids');
      expect(await service(client).syncNow(), isFalse);
      await settings.setFamilyCode('ABCDEFGHJKMNPQRS');
      expect(await service(client).syncNow(), isFalse);
      expect(client.puts, isEmpty);
    });

    test('on: sends under the family code, records the time, and waits 5 minutes between tries', () async {
      final client = _FakeClient();
      var t = DateTime(2026, 11, 20, 10);
      final s = service(client, now: () => t);
      await settings.setFamilyCode('ABCDEFGHJKMNPQRS');
      await settings.setRemoteSyncOn(true);
      expect(await s.maybeSync(), isTrue);
      expect(FamilySummary.decode(client.puts['ABCDEFGHJKMNPQRS']!).children.single.name, 'فداء');
      expect(await settings.lastRemoteSync(), t);
      client.puts.clear();
      t = t.add(const Duration(minutes: 2));
      expect(await s.maybeSync(), isFalse);
      expect(client.puts, isEmpty);
      expect(await s.maybeSync(force: true), isTrue, reason: 'leaving the app sends at once');
      t = t.add(const Duration(minutes: 6));
      client.fail = true;
      expect(await s.maybeSync(), isFalse, reason: 'no internet: quiet failure');
      expect(await settings.lastRemoteSync(), DateTime(2026, 11, 20, 10, 2));
    });

    test('the parent phone never sends, and nothing is sent before the service is set up', () async {
      final client = _FakeClient();
      await settings.setFamilyCode('ABCDEFGHJKMNPQRS');
      await settings.setRemoteSyncOn(true);
      expect(await service(client, configured: false).syncNow(), isFalse);
      await settings.setDeviceRole('parent');
      expect(await service(client).syncNow(), isFalse);
      expect(client.puts, isEmpty);
    });
  });

  group('the parent phone', () {
    Future<void> pump(WidgetTester tester, _FakeClient client, {Size size = const Size(360, 780)}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          remoteClientProvider.overrideWithValue(client),
          settingsRepositoryProvider.overrideWithValue(_Linked()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
          home: const RemoteViewScreen(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final size in const [Size(320, 640), Size(411, 891)]) {
      testWidgets('shows each girl\'s day without overflow (${size.width.toInt()}px)', (tester) async {
        final client = _FakeClient()
          ..doc = RemoteDoc(
            json: FamilySummary(children: [_summary()], dailyLimitMin: 45, madeAt: DateTime.now()).encode(),
            updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
          );
        await pump(tester, client, size: size);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('فداء'), findsWidgets);
        expect(find.textContaining('الأسبوع 3'), findsOneWidget);
        expect(find.textContaining('من 20 دقيقة'), findsOneWidget);
        expect(find.textContaining('25 دقيقة من 45'), findsOneWidget);
      });
    }

    testWidgets('no internet is explained gently', (tester) async {
      await pump(tester, _FakeClient()..offline = true);
      expect(find.text('مفيش اتصال'), findsOneWidget);
    });

    testWidgets('no data yet is explained gently', (tester) async {
      await pump(tester, _FakeClient());
      expect(find.text('لسه مفيش بيانات'), findsOneWidget);
    });
  });

  testWidgets('before Firebase is set up the dashboard says so', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: RemoteControls(configured: false))),
    ));
    expect(find.textContaining('لسه مش متجهّزة'), findsOneWidget);
  });

  test('time words', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(ago(now.subtract(const Duration(seconds: 30)), now), 'دلوقتي');
    expect(ago(now.subtract(const Duration(minutes: 15)), now), 'من 15 دقيقة');
    expect(ago(now.subtract(const Duration(hours: 5)), now), 'من 5 ساعة');
    expect(minutes(95), 'ساعة و35 دقيقة'.replaceFirst('ساعة', '1 ساعة'));
  });
}

class _Linked extends SettingsRepository {
  @override
  Future<String?> familyCode() async => 'ABCDEFGHJKMNPQRS';
}
