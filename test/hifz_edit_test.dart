import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/theme/app_theme.dart';
import 'package:nourfadaa/data/content/quran.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/data/providers.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:nourfadaa/features/parent/hifz_edit_screen.dart';
import 'package:nourfadaa/features/quran/hifz.dart';
import 'package:nourfadaa/features/quran/hifz_screens.dart';
import 'package:nourfadaa/features/quran/quran_screen.dart';

class _MemRepo extends HifzRepository {
  _MemRepo() : super(SettingsRepository());
  final saved = <int, HifzProgress>{};

  @override
  Future<HifzProgress> load({required int childId, required String name, required int age}) async =>
      saved[childId] ?? HifzProgress.initialFor(name: name, age: age);

  @override
  Future<void> save(int childId, HifzProgress p) async => saved[childId] = HifzProgress.decode(p.encode());
}

void main() {
  final q = QuranRepository.parse(File('assets/content/quran_surahs.json').readAsStringSync());

  testWidgets('a parent marks Al-Mujadila memorized and new memorization moves to Al-Hashr', (tester) async {
    tester.view.physicalSize = const Size(360, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _MemRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        childrenProvider.overrideWith((_) async => const [Child(id: 1, name: 'فداء', age: 5)]),
        quranContentProvider.overrideWith((_) async => q),
        hifzRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (ctx, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const HifzEditScreen(childId: 1),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('الآن: سورة المجادلة من الآية 1'), findsOneWidget);
    final row = find.byKey(const ValueKey('hifz-58'));
    await tester.ensureVisible(row);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<CheckboxListTile>(row).value, isTrue);
    expect(repo.saved[1]!.memorized.contains(58), isTrue);
    expect(repo.saved[1]!.currentSurah, 59);
  });
}
