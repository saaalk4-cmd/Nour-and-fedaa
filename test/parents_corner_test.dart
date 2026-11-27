import 'dart:io';

import 'package:buraq/core/widgets/pin_entry.dart';
import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/data/repositories/content_catalog.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/features/parent/change_pin_screen.dart';
import 'package:buraq/features/parent/parents_corner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _type(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.descendant(
        of: find.byType(PinEntry), matching: find.text(_ar(d))));
    await t.pump();
  }
  await t.pump();
}

String _ar(String d) => String.fromCharCode(0x0660 + int.parse(d));

class _MemSettings extends SettingsRepository {
  _MemSettings(this.pin);
  String pin;
  @override
  Future<bool> verifyPin(String p) async => p == pin;
  @override
  Future<void> setPin(String p) async => pin = p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    await databaseFactory
        .setDatabasesPath(Directory.systemTemp.createTempSync('buraq_test').path);
    await AppDatabase.instance.close();
  });

  test('catalog lists bundled lessons and level checks from assets', () async {
    final list = await ContentCatalog().entries();
    expect(list.any((e) => e.title.contains('الفاتحة')), isTrue);
    expect(list.where((e) => e.title.startsWith('اختبار المستوى')).length, 3);
    expect(list.every((e) => e.sourceTypes.isNotEmpty), isTrue);
    expect(list.every((e) => !e.verified), isTrue);
    final lessons = list.where((e) => e.title.startsWith('درس'));
    expect(
        lessons.every((e) =>
            e.audioStatus == 'لم يُسجَّل بعد' ||
            e.audioStatus!.startsWith('تلاوة أونلاين')),
        isTrue);
    expect(lessons.any((e) => e.audioStatus!.startsWith('تلاوة أونلاين')), isTrue);
  });

  testWidgets('parents corner shows sources with review status', (t) async {
    final entries = (await t.runAsync(() => ContentCatalog().entries()))!;
    await t.pumpWidget(ProviderScope(
      overrides: [contentCatalogProvider.overrideWith((_) async => entries)],
      child: const MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl, child: ParentsCornerScreen()),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('قسم الوالدين'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('اختبار المستوى – الأطفال'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('قيد المراجعة'), findsWidgets);
  });

  testWidgets('change pin: wrong current is refused, then full change works',
      (t) async {
    final mem = _MemSettings('1234');
    await t.pumpWidget(ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(mem)],
      child: const MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl, child: ChangePinScreen()),
      ),
    ));
    await t.pumpAndSettle();

    await _type(t, '9999');
    await t.pumpAndSettle();
    expect(find.text('الرمز الحالي غير صحيح'), findsOneWidget);

    await _type(t, '1234');
    await t.pumpAndSettle();
    expect(find.text('اختر رمزًا جديدًا'), findsOneWidget);

    await _type(t, '5555');
    await t.pumpAndSettle();
    expect(find.text('أعد إدخال الرمز الجديد'), findsOneWidget);
    await _type(t, '5555');
    await t.pumpAndSettle();
    expect(mem.pin, '5555');
  });

  testWidgets('change pin: mismatched confirmation keeps the old pin',
      (t) async {
    final mem = _MemSettings('1234');
    await t.pumpWidget(ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(mem)],
      child: const MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl, child: ChangePinScreen()),
      ),
    ));
    await _type(t, '1234');
    await t.pumpAndSettle();
    await _type(t, '5555');
    await t.pumpAndSettle();
    await _type(t, '6666');
    await t.pumpAndSettle();
    expect(mem.pin, '1234');
    expect(find.text('الرمزان غير متطابقين، حاول من جديد'), findsOneWidget);
  });
}
