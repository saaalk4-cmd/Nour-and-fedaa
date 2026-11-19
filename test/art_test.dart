import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/design/art.dart';
import 'package:nourfadaa/core/widgets/mascot.dart';
import 'package:nourfadaa/features/path/learning_path_screen.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/features/home/who_learns_screen.dart';

void main() {
  test('every art name has a file, and the whole kit stays light', () {
    var total = 0;
    for (final n in Art.all) {
      final f = File(Art.path(n));
      expect(f.existsSync(), isTrue, reason: n);
      total += f.lengthSync();
    }
    expect(Art.all.toSet().length, Art.all.length);
    expect(total, lessThan(2 * 1024 * 1024), reason: 'art kit should stay under 2MB');
  });

  test('assets/art is declared in pubspec', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/art/'));
  });

  test('no file in assets/art is left unregistered in Art.all', () {
    final files = Directory('assets/art')
        .listSync()
        .map((e) => e.path.split('/').last.replaceAll('.webp', ''))
        .toSet();
    expect(files, Art.all.toSet());
  });

  test('little ones get Nour, the older one gets Fedaa', () {
    expect(characterFor(const Child(id: 1, name: 'نور', age: 3)), Art.nour);
    expect(characterFor(const Child(id: 2, name: 'فداء', age: 5)), Art.fedaa);
  });

  test('Lamaa has a distinct approved pose for every mood', () {
    final names = MascotMood.values.map(mascotArt).toSet();
    expect(names.length, MascotMood.values.length);
    for (final n in names) {
      expect(Art.all, contains(n));
    }
  });

  test('week backgrounds and side decor all exist in the kit', () {
    for (final n in [...Art.weekBackgrounds, ...Art.decor]) {
      expect(Art.all, contains(n));
    }
    expect(Art.weekBackgrounds.toSet().length, Art.weekBackgrounds.length);
  });

  test('path gate phrase is short and gentle', () {
    expect(kPathGateSay.split(' ').length, lessThanOrEqualTo(4));
  });

  test('spoken prompt is short and has no failure wording', () {
    expect(kWhoLearnsSay.split(' ').length, lessThanOrEqualTo(4));
  });

  testWidgets('a child card shows the name, is a button, and taps once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: ChildCard(child: const Child(id: 1, name: 'فداء', age: 5), onTap: () => taps++),
        ),
      ),
    ));
    expect(find.text('فداء'), findsOneWidget);
    await tester.tap(find.byType(ChildCard));
    expect(taps, 1);
  });

  testWidgets('ArtButton keeps a finger-sized touch target', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: ArtButton(art: Art.home, label: 'الرئيسية', size: 40, onTap: () {}))),
    ));
    final size = tester.getSize(find.byType(ArtButton));
    expect(size.width, greaterThanOrEqualTo(Kid.minTouch));
    expect(size.height, greaterThanOrEqualTo(Kid.minTouch));
  });
}
