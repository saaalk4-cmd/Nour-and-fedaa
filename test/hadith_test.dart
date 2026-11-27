import 'package:buraq/data/providers.dart';
import 'package:buraq/data/quran/quran_source.dart';
import 'package:buraq/data/repositories/hadith_repository.dart';
import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:buraq/features/lesson/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hadith texts are stored as pasted from sunnah.com, with sources', () async {
    final repo = HadithRepository();
    final sneeze = await repo.byId('bukhari_6224');
    expect(sneeze.reference, 'صحيح البخاري ٦٢٢٤');
    expect(sneeze.url, 'https://sunnah.com/bukhari:6224');
    expect(sneeze.matn, contains('يَهْدِيكُمُ اللَّهُ وَيُصْلِحُ بَالَكُمْ'));
    final greet = await repo.byId('bukhari_6236');
    expect(greet.matn, contains('وَعَلَى مَنْ لَمْ تَعْرِفْ'));
    final meal = await repo.byId('bukhari_5458');
    expect(meal.matn, contains('غَيْرَ مَكْفِيٍّ'));
  });

  test('every hadith step points to an existing hadith; every surah is verifiable',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final repo = LessonRepository();
    final hadith = HadithRepository();
    for (final path in manifest.listAssets()) {
      if (!path.startsWith('assets/content/lessons/')) continue;
      final raw = await rootBundle.loadString(path);
      // لا نص قرآني مكتوب يدويًا في ملفات الدروس
      expect(raw.contains('ٱللَّهِ'), isFalse, reason: path);
      final l = await repo.byId(path.split('/').last.replaceAll('.json', ''));
      for (final s in l.steps) {
        if (s.type == StepType.hadith) await hadith.byId(s.hadith!);
        if (s.type == StepType.surah) {
          expect(kKnownAyahCounts.containsKey(s.surah), isTrue,
              reason: '${l.id}: surah ${s.surah}');
          expect(l.sourceType, 'quran');
        }
      }
    }
  });

  test('Quran lessons exist for every band; adhkar for 5-7', () async {
    final repo = LessonRepository();
    expect((await repo.bySection('t_listen', AgeBand.buraem)).length, 4);
    expect((await repo.bySection('quran', AgeBand.atfal)).length, 13);
    expect((await repo.bySection('quran', AgeBand.nashia)).length, 11);
    expect((await repo.bySection('quran', AgeBand.murahiqun)).length, 10);
    for (final band in AgeBand.values) {
      for (final l in await repo.bySection('quran', band)) {
        for (final s in l.steps.where((s) => s.type == StepType.surah)) {
          expect(kKnownAyahCounts.containsKey(s.surah), isTrue,
              reason: '${l.id}: سورة ${s.surah} بلا عدد آيات موثّق');
        }
      }
    }
    expect((await repo.bySection('adhkar', AgeBand.atfal)).length, 3);
  });

  testWidgets('hadith step shows the text, narrator and reference', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final lesson = Lesson.fromJson({
      'id': 'h',
      'title': 'أدب العطاس',
      'band': 'atfal',
      'source_type': 'sahih_sunnah',
      'steps': [
        {'type': 'hadith', 'hadith': 'bukhari_6224'},
        {'type': 'reward', 'stars': 3},
      ],
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LessonScreen(lessonId: 'h')),
    ]);
    final h = await t.runAsync(() => HadithRepository().byId('bukhari_6224'));
    await t.pumpWidget(ProviderScope(
      overrides: [
        lessonProvider('h').overrideWith((_) async => lesson),
        hadithProvider('bukhari_6224').overrideWith((_) async => h!),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('hadith_matn')), findsOneWidget);
    expect(find.textContaining('صحيح البخاري ٦٢٢٤'), findsOneWidget);
    expect(find.text('عن أبو هريرة رضي الله عنه'), findsOneWidget);
    expect(find.byKey(const Key('hadith_source')), findsOneWidget);
    expect(find.byKey(const Key('next_button')), findsOneWidget);
  });
}
