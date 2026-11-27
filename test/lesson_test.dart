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
  Future<void> play(Lesson lesson) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  audioTests();
  chooseTests();

  group('Lesson model', () {
    test('parses the bundled toddler Fatiha lesson (audio only, no typed text)',
        () async {
      final raw = await rootBundle
          .loadString('assets/content/lessons/t_listen_fatiha.json');
      final l = Lesson.fromJsonString(raw);
      expect(l.id, 't_listen_fatiha');
      expect(l.band, AgeBand.buraem);
      expect(l.sourceType, 'quran');
      expect(l.textFreeForChild, isTrue);
      expect(l.rewardStars, 3);
      expect(l.steps.first.type, StepType.surah);
      expect(l.steps.first.surah, 1);
      expect(raw.contains('بِسْمِ'), isFalse);
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

    test('audio requires a license', () {
      Map<String, dynamic> base() => {
            'id': 'x',
            'title': 'x',
            'band': 'buraem',
            'source_type': 'quran',
            'steps': [
              {'type': 'listen'}
            ],
          };
      expect(() => Lesson.fromJson({...base(), 'audio': 'assets/audio/x.mp3'}),
          throwsFormatException);
      expect(
          () => Lesson.fromJson({
                ...base(),
                'audio': 'assets/audio/x.mp3',
                'audio_license': '  ',
              }),
          throwsFormatException);
      final ok = Lesson.fromJson({
        ...base(),
        'audio': 'assets/audio/x.mp3',
        'audio_license': 'ترخيص تجريبي',
      });
      expect(ok.hasAudio, isTrue);
      expect(Lesson.fromJson(base()).hasAudio, isFalse);
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

    // البراعم: لا عنوان مكتوب للطفل
    expect(find.text('درس'), findsNothing);
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

void audioTests() {
  test('lesson without audio completes via fallback and never builds a player',
      () async {
    final audio = AssetLessonAudio(fallbackDuration: Duration.zero);
    final lesson = Lesson.fromJson({
      'id': 'x',
      'title': 'x',
      'band': 'buraem',
      'source_type': 'educational',
      'steps': [
        {'type': 'listen'}
      ],
    });
    await audio.play(lesson);
    await audio.stop();
  });
}

void chooseTests() {
  testWidgets('choose step: wrong answer allows retry, right answer unlocks next',
      (tester) async {
    final lesson = Lesson.fromJson({
      'id': 'c',
      'title': 'حروفي',
      'band': 'atfal',
      'source_type': 'educational',
      'steps': [
        {
          'type': 'choose',
          'prompt': 'ب',
          'question': 'أيّ صورة تبدأ بهذا الحرف؟',
          'options': ['🍎', '🦆'],
          'option_labels': ['تفاحة', 'بطة'],
          'answer': 1,
        },
        {'type': 'reward', 'stars': 3},
      ],
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LessonScreen(lessonId: 'c')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [lessonProvider('c').overrideWith((_) async => lesson)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    // الفئات الأكبر ترى العنوان
    expect(find.text('حروفي'), findsOneWidget);
    expect(find.text('ب'), findsOneWidget);

    await tester.tap(find.byKey(const Key('option_0')));
    await tester.pump();
    expect(find.text('حاول مرة أخرى'), findsOneWidget);
    expect(find.byKey(const Key('next_button')), findsNothing);

    await tester.tap(find.byKey(const Key('option_1')));
    await tester.pump();
    expect(find.text('حاول مرة أخرى'), findsNothing);
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('finish_button')), findsOneWidget);
  });

  test('choose step validation', () {
    Map<String, dynamic> step(Map<String, dynamic> extra) => {
          'id': 'x',
          'title': 'x',
          'band': 'atfal',
          'source_type': 'educational',
          'steps': [
            {'type': 'choose', 'question': 'q', ...extra}
          ],
        };
    expect(() => Lesson.fromJson(step({'options': ['a']})), throwsFormatException);
    expect(() => Lesson.fromJson(step({'options': ['a', 'b'], 'answer': 2})),
        throwsFormatException);
    expect(
        () => Lesson.fromJson(step({
              'options': ['a', 'b'],
              'option_labels': ['x'],
            })),
        throwsFormatException);
  });
}
