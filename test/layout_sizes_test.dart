import 'package:buraq/core/theme/app_theme.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:buraq/features/home/time_up_screen.dart';
import 'package:buraq/features/lesson/lesson_screen.dart';
import 'package:buraq/features/onboarding/account_screen.dart';
import 'package:buraq/features/onboarding/add_child_screen.dart';
import 'package:buraq/features/onboarding/band_confirm_screen.dart';
import 'package:buraq/features/onboarding/pin_setup_screen.dart';
import 'package:buraq/features/onboarding/welcome_screen.dart';
import 'package:go_router/go_router.dart';

Child _kid(int years) => Child(
    id: 1,
    nickname: 'نجمة',
    avatar: 'star',
    birthYear: DateTime.now().year - years,
    birthMonth: 1);

/// يتأكد أن الرئيسيات الأربع لا يحدث فيها تجاوز (overflow) على هاتف صغير
/// ومع خط كبير. أي تجاوز يظهر استثناءً في الاختبار.
void main() {
  screensTests();
  for (final (label, w, h, scale) in [
    ('small phone', 360.0, 640.0, 1.0),
    ('large text', 390.0, 844.0, 1.3),
  ]) {
    for (final age in [3, 6, 9, 13]) {
      testWidgets('$label, age $age: no overflow', (t) async {
        t.view.physicalSize = Size(w * 2, h * 2);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(ProviderScope(
          overrides: [dueReviewProvider.overrideWith((_) async => const [])],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child!),
            ),
            home: homeForBand(_kid(age), const {}),
          ),
        ));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }
}

void screensTests() {
  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'account': () => const AccountScreen(),
    'pin': () => const PinSetupScreen(),
    'add child': () => const AddChildScreen(),
    'band': () => const BandConfirmScreen(),
    'time up': () => const TimeUpScreen(),
    'akhlaq choose': () => const LessonScreen(lessonId: 'pv'),
  };
  final lesson = Lesson.fromJson({
    'id': 'pv',
    'title': 'لا للتنمّر',
    'icon': '🛡️',
    'band': 'nashia',
    'source_type': 'educational',
    'steps': [
      {
        'type': 'choose',
        'prompt': '🏫',
        'question': 'زملاؤك يسخرون من طالب جديد. ماذا تفعل؟',
        'options': ['أضحك معهم', 'أقف معه وأخبر المعلّم', 'أصوّره'],
        'answer': 1,
      },
      {'type': 'reward', 'stars': 3},
    ],
  });
  for (final (label, w, h, scale) in [
    ('small phone', 360.0, 640.0, 1.0),
    ('large text', 390.0, 844.0, 1.3),
  ]) {
    for (final e in screens.entries) {
      testWidgets('$label, ${e.key}: no overflow', (t) async {
        t.view.physicalSize = Size(w * 2, h * 2);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        final router = GoRouter(
            routes: [GoRoute(path: '/', builder: (_, __) => e.value())]);
        await t.pumpWidget(ProviderScope(
          overrides: [
            lessonProvider('pv').overrideWith((_) async => lesson),
            childDraftProvider.overrideWith((_) => ChildDraft(
                nickname: 'نجمة',
                birthYear: DateTime.now().year - 6,
                birthMonth: 1)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            routerConfig: router,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child!),
            ),
          ),
        ));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull);
      });
    }
  }
}
