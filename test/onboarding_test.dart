import 'package:buraq/core/theme/app_theme.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/features/onboarding/add_child_screen.dart';
import 'package:buraq/features/onboarding/band_confirm_screen.dart';
import 'package:buraq/features/onboarding/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget home, {ChildDraft? draft}) async {
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      if (draft != null) childDraftProvider.overrideWith((_) => draft),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    ),
  ));
  await t.pump();
}

ElevatedButton _next(WidgetTester t) =>
    t.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'التالي'));

void main() {
  testWidgets('welcome screen greets and offers to start', (t) async {
    await _pump(t, const WelcomeScreen());
    expect(find.text('أهلًا بك في براق'), findsOneWidget);
    expect(find.text('رحلة تعلّم من سنتين إلى ١٤ سنة'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });

  group('add child', () {
    testWidgets('next is disabled until everything is filled', (t) async {
      await _pump(t, const AddChildScreen());
      expect(_next(t).onPressed, isNull);
      expect(find.text('اللقب (ليس الاسم الحقيقي)'), findsOneWidget);
    });

    testWidgets('a valid draft enables next', (t) async {
      final y = DateTime.now().year - 5;
      await _pump(
        t,
        const AddChildScreen(),
        draft: ChildDraft(nickname: 'نجمة', birthYear: y, birthMonth: 1),
      );
      expect(_next(t).onPressed, isNotNull);
    });

    testWidgets('a child under two is blocked with a gentle message',
        (t) async {
      final y = DateTime.now().year;
      await _pump(
        t,
        const AddChildScreen(),
        draft: ChildDraft(nickname: 'نجمة', birthYear: y, birthMonth: 1),
      );
      expect(_next(t).onPressed, isNull);
      expect(find.textContaining('من سنتين'), findsOneWidget);
    });

    testWidgets('a teen over fourteen is blocked', (t) async {
      final y = DateTime.now().year - 16;
      await _pump(
        t,
        const AddChildScreen(),
        draft: ChildDraft(nickname: 'س', birthYear: y, birthMonth: 1),
      );
      expect(_next(t).onPressed, isNull);
      expect(find.textContaining('حتى ١٤'), findsOneWidget);
    });
  });

  group('band confirm', () {
    testWidgets('suggests the band from the age', (t) async {
      final y = DateTime.now().year - 9;
      await _pump(
        t,
        const BandConfirmScreen(),
        draft: ChildDraft(nickname: 'ن', birthYear: y, birthMonth: 1),
      );
      expect(find.text('نقترح لطفلك مسار الناشئة'), findsOneWidget);
      expect(find.text('٢ إلى ٤ سنوات — البراعم'), findsOneWidget);
      expect(find.text('١٢ إلى ١٤ سنوات — المراهقون'), findsOneWidget);
    });
  });
}
