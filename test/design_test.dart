import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/design/app_backdrop.dart';
import 'package:nourfadaa/core/design/pop_tap.dart';
import 'package:nourfadaa/core/design/section_tile.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
      home: AppBackdrop(child: Scaffold(body: SafeArea(child: child))),
    );

void main() {
  for (final size in const [Size(320, 568), Size(411, 891)]) {
    testWidgets('section tiles fit without overflow on ${size.width.toInt()}px, big text', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var tapped = 0;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.4)),
        child: host(
          GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
            children: [
              for (final t in const ['قرآني', 'أخلاقي الجميلة', 'سيرة نبينا ﷺ', 'قصص الأنبياء'])
                SectionTile(emoji: '📖', title: t, color: AppColors.teal, emojiSize: 58, onTap: () => tapped++),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('قرآني'));
      expect(tapped, 1);
    });
  }

  testWidgets('PopTap scales down while pressed and calls onTap', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(Center(child: PopTap(onTap: () => n++, child: const SizedBox(width: 80, height: 80)))));
    final g = await tester.startGesture(tester.getCenter(find.byType(PopTap)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, lessThan(1));
    await g.up();
    expect(n, 1);
  });
}
