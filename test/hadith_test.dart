import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/hadith.dart';

void main() {
  const assets = [
    'akhlaq_hadith',
    'adhkar_hadith',
    'prayer_hadith',
    'seerah_hadith',
  ];

  for (final name in assets) {
    test('$name: every hadith has narrator, book, number, grade and source url', () {
      final content = HadithRepository.parse(
        File('assets/content/$name.json').readAsStringSync(),
      );
      expect(content.hadiths, isNotEmpty);
      for (final h in content.hadiths) {
        expect(h.narrator, isNotEmpty, reason: h.id);
        expect(h.book, isNotEmpty, reason: h.id);
        expect(int.tryParse(h.number), isNotNull, reason: h.id);
        expect(h.grade, contains('صحيح'), reason: h.id);
        expect(h.url, startsWith('https://hadeethenc.com/'), reason: h.id);
      }
    });
  }

  test('a hadith missing its grade is rejected', () {
    expect(
      () => Hadith.fromJson({
        'id': 'x', 'title': 't', 'emoji': 'e', 'text': 'a', 'narrator': 'n',
        'book': 'b', 'number': '1', 'grade': '', 'url': 'u', 'kidMeaning': 'k',
      }),
      throwsFormatException,
    );
  });

  test('content without a declared source is rejected', () {
    expect(
      () => HadithRepository.parse('{"source":{"type":"x","name":""},"hadiths":[]}'),
      throwsFormatException,
    );
  });
}
