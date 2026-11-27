import 'dart:io';

import 'package:buraq/core/router/app_router.dart';
import 'package:buraq/core/theme/app_theme.dart';
import 'package:buraq/core/widgets/pin_entry.dart';
import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// يترك عمليات قاعدة البيانات الحقيقية تكتمل ثم يرسم.
Future<void> settle(WidgetTester t, [int ms = 60]) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// ينتظر ظهور عنصر بينما تكتمل عمليات قاعدة البيانات (بحد أقصى).
Future<void> waitFor(WidgetTester t, Finder f, {int tries = 30}) async {
  for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
    await settle(t);
  }
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  await settle(t);
}

Future<void> typePin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.descendant(
        of: find.byType(PinEntry),
        matching: find.text(String.fromCharCode(0x0660 + int.parse(d)))));
    await t.pump();
  }
  await settle(t);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('a parent signs up, adds a 6-year-old, and the child earns stars',
      (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await AppDatabase.instance.close();
      await databaseFactory.setDatabasesPath(
          Directory.systemTemp.createTempSync('buraq_e2e').path);
    });
    final lesson =
        (await t.runAsync(() => LessonRepository().byId('a_arabic_letters_1')))!;
    final year = DateTime.now().year - 6;

    await t.pumpWidget(ProviderScope(
      overrides: [
        // اختيار الشهر والسنة من القوائم يُختبر في onboarding_test؛ هنا نبدأ بمسودة جاهزة.
        childDraftProvider.overrideWith((_) =>
            ChildDraft(nickname: 'نجمة', birthYear: year, birthMonth: 1)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ));
    await settle(t);

    // ترحيب ← حساب (وضع محلي في الاختبار)
    await tapText(t, 'ابدأ');
    await t.enterText(find.byKey(const Key('email_field')), 'parent@example.com');
    await t.enterText(find.byKey(const Key('password_field')), '123456');
    await tapText(t, 'إنشاء الحساب');

    // الرمز السري مرتين
    expect(
        await t.runAsync(() => SettingsRepository().read('account_email')),
        'parent@example.com');
    await typePin(t, '1234');
    await typePin(t, '1234');

    // إضافة الطفل ← تأكيد الفئة ← تخطي الاختبار ← جاهز
    await tapText(t, 'التالي');
    await tapText(t, 'تأكيد');
    await tapText(t, 'تخطَّ الآن');
    await tapText(t, 'ادخل إلى براق');
    await waitFor(t, find.text('ابدأ أول درس'));
    expect(find.text('ابدأ أول درس'), findsOneWidget);

    // «ابدأ أول درس» ← أول درس حروف
    await tapText(t, 'ابدأ أول درس');
    await waitFor(t, find.byKey(const Key('listen_button')));
    expect(find.textContaining(lesson.title), findsOneWidget);

    // استماع (صوت محاكى) ثم التالي
    await t.tap(find.byKey(const Key('listen_button')));
    await t.pump(const Duration(seconds: 3));
    await settle(t);
    await t.tap(find.byKey(const Key('next_button')));
    await settle(t);

    // أسئلة الاختيار: الإجابة الصحيحة من بيانات الدرس نفسها
    for (final s in lesson.steps.where((s) => s.type == StepType.choose)) {
      await t.tap(find.byKey(Key('option_${s.answer}')));
      await t.pump();
      await t.tap(find.byKey(const Key('next_button')));
      await settle(t);
    }

    // المكافأة تُحفظ في قاعدة البيانات
    expect(find.byKey(const Key('finish_button')), findsOneWidget);
    await settle(t, 400);
    final kids = (await t.runAsync(() => ChildRepository().all()))!;
    expect(kids.single.nickname, 'نجمة');
    expect(kids.single.stars, lesson.rewardStars);
    await t.runAsync(() => AppDatabase.instance.close());
  });
}
