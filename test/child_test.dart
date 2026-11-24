import 'package:buraq/data/models/child.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:flutter_test/flutter_test.dart';

Child _child(
        {int year = 2022, int month = 3, AgeBand? override, int stars = 0}) =>
    Child(
      id: 1,
      nickname: 'نجمة',
      avatar: 'star',
      birthYear: year,
      birthMonth: month,
      bandOverride: override,
      stars: stars,
    );

void main() {
  final now = DateTime(2026, 11, 24);

  test('band follows age when not overridden', () {
    expect(_child(year: 2022).band(now: now), AgeBand.buraem); // 4
    expect(_child(year: 2021).band(now: now), AgeBand.atfal); // 5
    expect(_child(year: 2017).band(now: now), AgeBand.nashia); // 9
    expect(_child(year: 2013).band(now: now), AgeBand.murahiqun); // 13
  });

  test('parent override wins over the age-based band', () {
    final c = _child(year: 2022, override: AgeBand.atfal);
    expect(c.band(now: now), AgeBand.atfal);
  });

  test('level rises every 10 stars', () {
    expect(_child(stars: 0).level, 1);
    expect(_child(stars: 25).level, 3);
  });

  test('avatar emoji falls back to star', () {
    expect(Avatars.emoji('leaf'), '🍃');
    expect(Avatars.emoji('unknown'), '⭐');
  });

  group('ChildDraft', () {
    test('is incomplete until nickname and birth date exist', () {
      const d = ChildDraft();
      expect(d.isComplete, isFalse);
      expect(d.copyWith(nickname: 'نجمة').isComplete, isFalse);
      expect(
        d.copyWith(nickname: 'نجمة', birthYear: 2022, birthMonth: 3).isComplete,
        isTrue,
      );
    });

    test('blank nickname is not complete', () {
      const d = ChildDraft(nickname: '  ', birthYear: 2022, birthMonth: 3);
      expect(d.isComplete, isFalse);
    });

    test('age is computed from birth date', () {
      const d = ChildDraft(birthYear: 2022, birthMonth: 12);
      expect(d.ageYears(now: DateTime(2026, 11, 24)), 3);
    });
  });
}
