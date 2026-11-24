import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:buraq/features/home/section_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson _lesson(String band) => Lesson.fromJson({
      'id': 'x',
      'title': 'عنوان الدرس',
      'icon': '🍽️',
      'section': 't_adab',
      'band': band,
      'source_type': 'educational',
      'steps': [
        {'type': 'listen'}
      ],
    });

Child _child(int age) => Child(
      id: 1,
      nickname: 'ن',
      avatar: 'star',
      birthYear: DateTime.now().year - age,
      birthMonth: 1,
    );

Future<void> _show(WidgetTester t, int age, String lessonBand) async {
  final lesson = _lesson(lessonBand);
  await t.pumpWidget(ProviderScope(
    overrides: [
      selectedChildProvider.overrideWith((_) async => _child(age)),
      sectionLessonsProvider((section: 't_adab', band: bandForAge(age)))
          .overrideWith((_) async => [lesson]),
    ],
    child: const MaterialApp(
      home: Directionality(
          textDirection: TextDirection.rtl,
          child: SectionScreen(sectionId: 't_adab')),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('toddler sees icons only: no lesson title and no section name',
      (t) async {
    await _show(t, 3, 'buraem');
    expect(find.text('🍽️'), findsOneWidget);
    expect(find.text('عنوان الدرس'), findsNothing);
    expect(find.text('آدابي'), findsNothing);
    // الاسم متاح لقارئ الشاشة
    expect(find.bySemanticsLabel('عنوان الدرس'), findsOneWidget);
  });

  testWidgets('older bands still see the written title', (t) async {
    await _show(t, 9, 'nashia');
    expect(find.text('عنوان الدرس'), findsOneWidget);
  });
}
