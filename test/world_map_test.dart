import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/design/art.dart';
import 'package:nourfadaa/features/world/world_map.dart';

void main() {
  for (final w in const [320.0, 411.0]) {
    testWidgets('the world map fits ${w.toInt()}px and every stop opens its section', (tester) async {
      tester.view.physicalSize = Size(w, 2000) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      final titles = ['قرآني', 'صلاتي', 'أذكاري', 'أخلاقي الجميلة', 'سيرة', 'أبطال', 'الأنبياء', 'أتعلم'];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WorldMap(stops: [
                for (final t in titles) MapStop(art: Art.secQuran, title: t, color: Colors.teal, onTap: () => opened.add(t)),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final t in titles) {
        await tester.tap(find.bySemanticsLabel(t));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(opened, titles);
    });
  }

  test('stops zig-zag down the trail', () {
    expect(WorldMap.centerOf(0, 400).dx, lessThan(WorldMap.centerOf(1, 400).dx));
    expect(WorldMap.centerOf(1, 400).dy, greaterThan(WorldMap.centerOf(0, 400).dy));
    expect(WorldMap.heightFor(8), greaterThan(WorldMap.centerOf(7, 400).dy + 90));
  });
}
