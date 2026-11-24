import 'dart:io';
import 'package:buraq/data/lesson_audio.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:buraq/features/lesson/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/data/models/child.dart';

class _FastAudio implements LessonAudio {
  @override
  Future<void> play(String lessonId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lesson model', () {
    test('parses the bundled toddler lesson', () async {
      final raw = await rootBundle
          .loadString('assets/content/lessons/t_listen_fatiha.json');
      final l = Lesson.fromJsonString(raw);
      expect(l.id, 't_listen_fatiha');
      expect(l.band, AgeBand.buraem);
      expect(l.sourceType, 'quran');
      expect(l.contentVerified, isFalse);
      expect(l.rewardStars, 3);
      expect(l.steps.map((s) => s.type),
          [StepType.listen, StepType.repeat, StepType.reward]);
      // لا نص قرآني في الملف
      expect(raw.contains('بسم'), isFalse);
    });

    test('rejects missing source_type', () {
      expect(
        () => Lesson.fromJson({
          'id': 'x',
          'title': 'x',
          'band': 'buraem',
          'steps': [
            {'type': 'listen'}
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects empty steps and unknown band', () {
      expect(
        () => Lesson.fromJson({
          'id': 'x',
          'title': 'x',
          'band': 'buraem',
          'source_type': 'quran',
          'steps': [],
        }),
        throwsFormatException,
      );
      expect(
        () => Lesson.fromJson({
          'id': 'x',
          'title': 'x',
          'band': 'zzz',
          'source_type': 'quran',
          'steps': [
            {'type': 'listen'}
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('Progress', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      await databaseFactory
        .setDatabasesPath(Directory.systemTemp.createTempSync('buraq_test').path);
      await AppDatabase.instance.close();
    });

    test('stars awarded once only', () async {
      final id = await ChildRepository().add(const ChildDraft(
        nickname: 'نجم',
        avatar: 'star',
        birthYear: 2022,
        birthMonth: 1,
      ));
      final repo = ProgressRepository();
      expect(await repo.complete(childId: id, lessonId: 'a', stars: 3), 3);
      expect(await repo.complete(childId: id, lessonId: 'a', stars: 3), 0);
      expect(await repo.isDone(id, 'a'), isTrue);
      final child = await ChildRepository().byId(id);
      expect(child!.stars, 3);
    });
  });

  testWidgets('lesson flow: listen, repeat x3, reward', (tester) async {
    final lesson = Lesson.fromJson({
      'id': 't',
      'title': 'درس',
      'band': 'buraem',
      'source_type': 'educational',
      'steps': [
        {'type': 'listen'},
        {'type': 'repeat', 'times': 3},
        {'type': 'reward', 'stars': 3},
      ],
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LessonScreen(lessonId: 't')),
      GoRoute(path: '/home', builder: (_, __) => const Text('home')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lessonProvider('t').overrideWith((_) async => lesson),
        lessonAudioProvider.overrideWithValue(_FastAudio()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('next_button')), findsNothing);
    await tester.tap(find.byKey(const Key('listen_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      expect(find.byKey(const Key('next_button')), findsNothing);
      await tester.tap(find.byKey(const Key('repeat_button')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('finish_button')), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('finish_button')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
