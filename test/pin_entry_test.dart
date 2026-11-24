import 'package:buraq/core/widgets/pin_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester t, ValueChanged<String> onDone,
      {String? error}) async {
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(body: PinEntry(onCompleted: onDone, error: error)),
    ));
  }

  testWidgets('calls onCompleted with the 4 digits typed', (t) async {
    String? got;
    await pump(t, (p) => got = p);
    for (final d in ['1', '2', '3', '4']) {
      await t.tap(find.byKey(ValueKey('key_$d')));
      await t.pump();
    }
    await t.pump();
    expect(got, '1234');
  });

  testWidgets('backspace removes the last digit', (t) async {
    String? got;
    await pump(t, (p) => got = p);
    await t.tap(find.byKey(const ValueKey('key_9')));
    await t.tap(find.byKey(const ValueKey('key_back')));
    for (final d in ['1', '2', '3', '4']) {
      await t.tap(find.byKey(ValueKey('key_$d')));
      await t.pump();
    }
    await t.pump();
    expect(got, '1234');
  });

  testWidgets('keypad shows Arabic-Indic digits', (t) async {
    await pump(t, (_) {});
    expect(find.text('٥'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('shows an error message when given', (t) async {
    await pump(t, (_) {}, error: 'الرمز غير صحيح');
    expect(find.text('الرمز غير صحيح'), findsOneWidget);
  });
}
