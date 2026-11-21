import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/quran.dart';
import 'package:nourfadaa/features/quran/hifz.dart';
import 'package:nourfadaa/features/quran/hifz_review.dart';

void main() {
  final q = QuranRepository.parse(File('assets/content/quran_surahs.json').readAsStringSync());
  final fedaa = HifzProgress.initialFor(name: 'فداء', age: 5).memorized;

  test('order rounds use only memorized surahs, consecutive ayat, really shuffled', () {
    final r = HifzReview(q, fedaa, rng: Random(1));
    for (var i = 0; i < 200; i++) {
      final o = r.order()!;
      expect(fedaa.contains(o.correct.first.surah), isTrue);
      expect(o.correct.length, inInclusiveRange(3, 4));
      for (var k = 1; k < o.correct.length; k++) {
        expect(o.correct[k].ayah, o.correct[k - 1].ayah + 1);
        expect(o.correct[k].surah, o.correct.first.surah);
      }
      expect(o.shuffled.toSet(), o.correct.toSet());
      expect(o.shuffled, isNot(equals(o.correct)));
    }
  });

  test('next-ayah rounds: the answer follows the heard ayah, options are distinct', () {
    final r = HifzReview(q, fedaa, rng: Random(2));
    for (var i = 0; i < 200; i++) {
      final n = r.next()!;
      final right = n.options[n.answer];
      expect(right.surah, n.heard.surah);
      expect(right.ayah, n.heard.ayah + 1);
      expect(n.options.toSet().length, 3);
      expect(n.options.contains(n.heard), isFalse);
      expect(fedaa.contains(n.heard.surah), isTrue);
    }
  });

  test('nothing to play without memorized surahs', () {
    final r = HifzReview(q, <int>{});
    expect(r.canPlay, isFalse);
    expect(r.order(), isNull);
    expect(r.next(), isNull);
  });
}
