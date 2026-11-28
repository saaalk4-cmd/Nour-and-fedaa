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

  test('hadith texts are stored as pasted from sunnah.com, with sources',
      () async {
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

  test('hadith texts from the open hadith-api set, with references', () async {
    final repo = HadithRepository();
    final pillars = await repo.byId('bukhari_8');
    expect(pillars.reference, 'صحيح البخاري ٨');
    expect(pillars.matn, contains('بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ'));
    final food = await repo.byId('bukhari_5376');
    expect(food.matn, contains('وَكُلْ بِيَمِينِكَ'));
    final sleep = await repo.byId('bukhari_6324');
    expect(sleep.matn, contains('أَمُوتُ وَأَحْيَا'));
    final jibril = await repo.byId('muslim_8');
    expect(jibril.reference, 'صحيح مسلم ٨');
    expect(jibril.url, 'https://sunnah.com/muslim:8a');
    expect(jibril.matn, contains('جِبْرِيلُ أَتَاكُمْ'));
    // لا علامات اتجاه خفية ولا علامات تنصيص غير مغلقة.
    final wudu = await repo.byId('bukhari_159');
    expect(wudu.matn, contains('إِلَى الْمِرْفَقَيْنِ'));
    final best = await repo.byId('bukhari_527');
    expect(best.matn, contains('الصَّلاَةُ عَلَى وَقْتِهَا'));
    final twoWords = await repo.byId('bukhari_6406');
    expect(twoWords.matn, contains('سُبْحَانَ اللَّهِ الْعَظِيمِ'));
    final tasbih = await repo.byId('bukhari_6405');
    expect(tasbih.matn, contains('زَبَدِ الْبَحْرِ'));
    final takbir = await repo.byId('bukhari_789');
    expect(takbir.matn, contains('رَبَّنَا لَكَ الْحَمْدُ'));
    final istighfar = await repo.byId('bukhari_6307');
    expect(istighfar.matn, contains('أَكْثَرَ مِنْ سَبْعِينَ مَرَّةً'));
    for (final h in [
      pillars,
      food,
      sleep,
      jibril,
      wudu,
      best,
      twoWords,
      tasbih,
      istighfar
    ]) {
      expect(h.matn.contains('\u200f'), isFalse, reason: h.id);
      expect('«'.allMatches(h.matn).length, '»'.allMatches(h.matn).length,
          reason: h.id);
    }
  });

  test(
      'every hadith step points to an existing hadith; every surah is verifiable',
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
    expect((await repo.bySection('t_letters', AgeBand.buraem)).length, 8);
    expect((await repo.bySection('t_salah', AgeBand.buraem)).length, 3);
    expect((await repo.bySection('t_know', AgeBand.buraem)).length, 3);
    // كل دروس البراعم (عدا السور) لها ملف صوت موجود.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    for (final sec in ['t_adab', 't_akhlaq', 't_letters', 't_salah', 't_know']) {
      for (final l in await repo.bySection(sec, AgeBand.buraem)) {
        expect(l.audio, isNotNull, reason: l.id);
        expect(assets.contains(l.audio), isTrue, reason: l.audio);
      }
    }
    // البراعم كلها روجعت شرعيًا (٢٨ نوفمبر ٢٠٢٦).
    for (final sec in ['t_listen', 't_adab', 't_akhlaq', 't_letters', 't_salah', 't_know']) {
      for (final l in await repo.bySection(sec, AgeBand.buraem)) {
        expect(l.contentVerified, isTrue, reason: l.id);
      }
    }
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
    expect((await repo.bySection('adhkar', AgeBand.atfal)).length, 5);
    expect((await repo.bySection('aqeedah', AgeBand.atfal)).length, 4);
    expect((await repo.bySection('aqeedah', AgeBand.nashia)).length, 1);
    expect((await repo.bySection('aqeedah', AgeBand.murahiqun)).length, 1);
    expect((await repo.bySection('prayer', AgeBand.nashia)).length, 1);
    expect((await repo.bySection('prayer', AgeBand.murahiqun)).length, 1);
    expect((await repo.bySection('adhkar', AgeBand.nashia)).length, 1);
    expect((await repo.bySection('adhkar', AgeBand.murahiqun)).length, 2);
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
