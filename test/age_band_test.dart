import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/arabic_digits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ageInYears', () {
    final now = DateTime(2026, 11, 24);

    test('birthday not reached yet this year', () {
      expect(ageInYears(2022, 12, now: now), 3);
    });

    test('birthday already passed this year', () {
      expect(ageInYears(2022, 11, now: now), 4);
      expect(ageInYears(2022, 3, now: now), 4);
    });

    test('never negative', () {
      expect(ageInYears(2030, 1, now: now), 0);
    });
  });

  group('bandForAge', () {
    test('boundaries of the four bands', () {
      expect(bandForAge(2), AgeBand.buraem);
      expect(bandForAge(4), AgeBand.buraem);
      expect(bandForAge(5), AgeBand.atfal);
      expect(bandForAge(7), AgeBand.atfal);
      expect(bandForAge(8), AgeBand.nashia);
      expect(bandForAge(11), AgeBand.nashia);
      expect(bandForAge(12), AgeBand.murahiqun);
      expect(bandForAge(14), AgeBand.murahiqun);
    });

    test('out of range is clamped to nearest band', () {
      expect(bandForAge(0), AgeBand.buraem);
      expect(bandForAge(16), AgeBand.murahiqun);
    });
  });

  test('supported age range is 2 to 14', () {
    expect(isSupportedAge(1), isFalse);
    expect(isSupportedAge(2), isTrue);
    expect(isSupportedAge(14), isTrue);
    expect(isSupportedAge(15), isFalse);
  });

  test('band labels and ranges', () {
    expect(AgeBand.buraem.label, 'البراعم');
    expect(AgeBand.buraem.rangeLabel, '٢ إلى ٤ سنوات');
    expect(AgeBand.murahiqun.rangeLabel, '١٢ إلى ١٤ سنوات');
  });

  test('byName resolves stored names', () {
    expect(AgeBand.byName('nashia'), AgeBand.nashia);
    expect(AgeBand.byName(null), isNull);
    expect(AgeBand.byName('x'), isNull);
  });

  test('toArabicDigits converts only digits', () {
    expect(toArabicDigits(2026), '٢٠٢٦');
    expect(toArabicDigits('12 من 20'), '١٢ من ٢٠');
    expect(toArabicDigits('abc'), 'abc');
  });
}
