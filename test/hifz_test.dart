import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/quran.dart';
import 'package:nourfadaa/features/quran/hifz.dart';

void main() {
  final q = QuranRepository.parse(File('assets/content/quran_surahs.json').readAsStringSync());

  test('Fedaa starts with At-Talaq to An-Nas memorized and Al-Mujadila as new; Nour only listens', () {
    final f = HifzProgress.initialFor(name: 'فداء', age: 5);
    expect(f.memorized.length, 50);
    expect(f.statusOf(65), HifzStatus.memorized);
    expect(f.statusOf(114), HifzStatus.memorized);
    expect(f.statusOf(58), HifzStatus.fresh);
    expect(f.nextNew(q), const AyahRange(58, 1, 3));
    final n = HifzProgress.initialFor(name: 'نور', age: 3);
    expect(n.memorized, isEmpty);
    expect(n.nextNew(q), isNull);
    expect(n.nextReview(q), isEmpty);
  });

  test('three new ayat a day, moving to the next surah when one is finished', () {
    final p = HifzProgress.initialFor(name: 'فداء', age: 5);
    final w = p.wirdFor('2026-11-21', q);
    expect(w.newPart, const AyahRange(58, 1, 3));
    expect(w.newDone, isFalse);
    p.completeNew('2026-11-21', q);
    expect(p.statusOf(58), HifzStatus.learning);
    // نفس اليوم: لا يتقدم مرتين، والورد يعرض ما أُنجز.
    p.completeNew('2026-11-21', q);
    expect(p.wirdFor('2026-11-21', q).newPart, const AyahRange(58, 1, 3));
    expect(p.wirdFor('2026-11-21', q).newDone, isTrue);
    expect(p.wirdFor('2026-11-22', q).newPart, const AyahRange(58, 4, 6));
    // المجادلة 22 آية: آخر مقطع 22-22 ثم الحشر.
    var day = 22;
    while (p.currentSurah == 58) {
      p.completeNew('2026-11-${day++}', q);
    }
    expect(p.statusOf(58), HifzStatus.memorized);
    expect(p.nextNew(q), const AyahRange(59, 1, 3));
  });

  test('daily review rotates through memorized surahs within a small budget', () {
    final p = HifzProgress.initialFor(name: 'فداء', age: 5);
    final r1 = p.wirdFor('2026-11-21', q).review;
    expect(r1, [114, 113, 112]);
    p.completeReview('2026-11-21', q);
    expect(p.wirdFor('2026-11-21', q).reviewDone, isTrue);
    expect(p.wirdFor('2026-11-21', q).review, r1, reason: 'today keeps its list');
    final r2 = p.wirdFor('2026-11-22', q).review;
    expect(r2.first, 111);
    final total = r2.map((s) => q.surahs.firstWhere((x) => x.surahNumber == s).ayahs.length).reduce((a, b) => a + b);
    expect(total, lessThanOrEqualTo(20));
    // سورة طويلة (الملك 30 آية) تُراجع وحدها.
    p.reviewIdx = p.memorized.toList().length - 1 - (p.memorized.toList()..sort()).indexOf(67);
    final long = p.nextReview(q);
    expect(long.first, 67);
    expect(long.length, 1);
  });

  test('progress survives saving and loading', () {
    final p = HifzProgress.initialFor(name: 'فداء', age: 5)
      ..completeNew('2026-11-21', q)
      ..completeReview('2026-11-21', q)
      ..listened.add(112)
      ..setMemorized(64, true);
    final back = HifzProgress.decode(p.encode());
    expect(back.nextNew(q), const AyahRange(58, 4, 6));
    expect(back.reviewIdx, p.reviewIdx);
    expect(back.memorized.contains(64), isTrue);
    expect(back.listened, {112});
    expect(back.wirdFor('2026-11-21', q).allDone, isTrue);
  });

  test('juz of a surah', () {
    expect([juzOfSurah(58), juzOfSurah(66), juzOfSurah(67), juzOfSurah(77), juzOfSurah(78), juzOfSurah(114), juzOfSurah(1)],
        [28, 28, 29, 29, 30, 30, null]);
  });
}
