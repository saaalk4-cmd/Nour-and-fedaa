import 'package:buraq/core/theme/app_theme.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/features/home/home_screen.dart';
import 'package:buraq/features/home/kids_home.dart';
import 'package:buraq/features/home/teen_home.dart';
import 'package:buraq/features/home/toddler_home.dart';
import 'package:buraq/features/home/tween_home.dart';
import 'package:buraq/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Child _childBornYearsAgo(int years) => Child(
      id: 1,
      nickname: 'نجمة',
      avatar: 'star',
      birthYear: DateTime.now().year - years,
      birthMonth: 1,
    );

Future<void> _show(WidgetTester t, Widget home,
    {List<String> dueIds = const []}) async {
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      dueReviewProvider.overrideWith((_) async => dueIds),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    ),
  ));
  await t.pump();
}

void main() {
  testWidgets('toddler review button shows only when something is due',
      (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(3), const {}));
    expect(find.byKey(const Key('review_button')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await _show(t, homeForBand(_childBornYearsAgo(3), const {}),
        dueIds: const ['t_adab_food']);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('review_button')), findsOneWidget);
  });

  testWidgets('age 3 gets the toddler home', (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(3), const {}));
    expect(find.byType(ToddlerHome), findsOneWidget);
    expect(find.text('أهلًا يا نجمة'), findsOneWidget);
    expect(find.text('أسمع وأردد'), findsOneWidget);
    expect(find.text('حديقتي'), findsOneWidget);
  });

  testWidgets('age 6 gets the kids home with locked sections', (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(6), const {}));
    expect(find.byType(KidsHome), findsOneWidget);
    expect(find.text('قرآني'), findsOneWidget);
    expect(find.text('ما لا يسع الطفل جهله'), findsOneWidget);
    expect(find.text('قريبًا إن شاء الله', skipOffstage: false), findsNothing);
  });

  testWidgets('age 9 gets the tween home', (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(9), const {}));
    expect(find.byType(TweenHome), findsOneWidget);
    expect(find.text('تحدّي اليوم'), findsOneWidget);
    expect(find.text('هدف اليوم'), findsOneWidget);
  });

  testWidgets('age 13 gets the teen home', (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(13), const {}));
    expect(find.byType(TeenHome), findsOneWidget);
    expect(find.text('درسك التالي'), findsOneWidget);
    await t.scrollUntilVisible(find.text('اسأل ولي أمرك'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('اسأل ولي أمرك'), findsOneWidget);
  });

  testWidgets('a section the parent turned off is hidden', (t) async {
    await _show(t, homeForBand(_childBornYearsAgo(6), const {'quran': false}));
    expect(find.text('قرآني'), findsNothing);
    expect(find.text('صلاتي'), findsOneWidget);
  });
}
