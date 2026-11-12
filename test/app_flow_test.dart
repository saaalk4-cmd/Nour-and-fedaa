import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/app.dart';
import 'package:nourfadaa/core/audio/sound_service.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/data/repositories/child_repository.dart';
import 'package:nourfadaa/data/repositories/gamification_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SilentPlayer implements SoundPlayer {
  @override
  Future<void> play(SoundEffect effect) async {}
}

/// ينتظر ظهور عنصر (قاعدة البيانات حقيقية، لذلك نترك الوقت يمر فعليًا).
Future<void> waitFor(WidgetTester tester, Finder finder, {int tries = 120}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // الاهتزاز يستدعي قناة المنصة: نتجاهلها في الاختبار.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );

  await tester.runAsync(() => AppDatabase.instance.resetForTest());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundServiceProvider.overrideWithValue(
          SoundService(
            player: _SilentPlayer(),
            readEnabled: () async => false,
            writeEnabled: (_) async {},
          ),
        ),
      ],
      child: const NourFadaaApp(),
    ),
  );
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Nour completes a lesson with one gentle mistake and progress is saved',
      (tester) async {
    await startApp(tester);
    try {
      await _nourLessonFlow(tester);
    } finally {
      await disposeApp(tester);
    }
  });

  testWidgets('parent creates a PIN and sees both daughters in the dashboard',
      (tester) async {
    await startApp(tester);
    try {
      await _parentFlow(tester);
    } finally {
      await disposeApp(tester);
    }
  });
}

Future<void> _nourLessonFlow(WidgetTester tester) async {
  // من سيتعلم اليوم؟ (ننتظر تحميل الطفلتين من القاعدة)
  await waitFor(tester, find.text('من سيتعلم اليوم؟'));
  await waitFor(tester, find.text('👧 فداء — 5 سنوات'));
  await tapText(tester, '👧 نور — 3 سنوات');

  // الشاشة الرئيسية: تحية + مهام اليوم
  await waitFor(tester, find.textContaining('أهلًا يا نور'));
  await waitFor(tester, find.text('مهام اليوم'));

  // قسم «أتعلم» ← الدرس
  await tapText(tester, 'أتعلم');
  await tapText(tester, 'ألوان جميلة');

  // 3 خطوات
  await waitFor(tester, find.text('الفراولة حمراء'));
  await tapText(tester, 'التالي');
  await waitFor(tester, find.text('الشمس صفراء'));
  await tapText(tester, 'التالي');
  await waitFor(tester, find.text('البحر أزرق'));
  await tapText(tester, 'التالي');

  // السؤال 1: صحيح من أول مرة
  await waitFor(tester, find.text('ما لون الشمس؟'));
  await tapText(tester, 'أصفر 🟡');
  await waitFor(tester, find.text('أحسنتِ! ✨'));
  await tapText(tester, 'التالي');

  // السؤال 2: خطأ لطيف أولًا (لا فشل ولا عقاب) ثم الصحيح
  await waitFor(tester, find.text('ما لون الفراولة؟'));
  await tapText(tester, 'أزرق 🔵');
  expect(find.text('قريب جدًا ❤️'), findsOneWidget);
  expect(find.textContaining('خطأ'), findsNothing);
  await tapText(tester, 'أحمر 🔴');
  await waitFor(tester, find.text('أحسنتِ! ✨'));
  await tapText(tester, 'أنهيتُ الدرس 🎉');

  // شاشة الاحتفال: 10 + إجابة صحيحة واحدة من أول مرة (5) = 15 XP ونجمة واحدة
  await waitFor(tester, find.text('⚡ +15 XP'));
  expect(find.text('⭐ +1 نجمة'), findsOneWidget);
  await tapText(tester, 'متابعة');

  // رجوع لقائمة الدروس والدرس عليه علامة الإكمال
  await waitFor(tester, find.text('✅'));

  // التقدم محفوظ فعليًا في قاعدة البيانات
  final saved = await tester.runAsync(() async {
    final nour = (await ChildRepository().all()).firstWhere((c) => c.name == 'نور');
    final game = GamificationRepository();
    return (await game.profile(nour.id), await game.completedLessonIds(nour.id));
  });
  expect(saved!.$1.xp, 15);
  expect(saved.$1.stars, 1);
  expect(saved.$2, {'learn_colors_basic'});
}

Future<void> _parentFlow(WidgetTester tester) async {
  await waitFor(tester, find.text('👧 نور — 3 سنوات'));
  await tapText(tester, 'لوحة ولي الأمر');
  await waitFor(tester, find.text('أنشئ رمز PIN من 4 أرقام'));

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '1234');
  await tester.enterText(fields.at(1), '1234');
  await tapText(tester, 'حفظ');

  await waitFor(tester, find.text('تقدم الطفلتين'));
  await waitFor(tester, find.text('👧 نور — 3 سنوات'));
  expect(find.text('👧 فداء — 5 سنوات'), findsOneWidget);
  expect(find.textContaining('لا يوجد نشاط بعد'), findsWidgets);
}
