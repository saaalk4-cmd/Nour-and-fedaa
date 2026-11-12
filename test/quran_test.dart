import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/quran.dart';

void main() {
  final content = QuranRepository.parse(
    File('assets/content/quran_surahs.json').readAsStringSync(),
  );

  test('quran asset declares a source and the right ayah counts', () {
    expect(content.sourceName, contains('Tanzil'));
    final counts = {for (final s in content.surahs) s.surahNumber: s.ayahs.length};
    expect(counts, {1: 7, 103: 3, 106: 4, 108: 3, 110: 3, 112: 4, 113: 5, 114: 6});
  });

  test('ayahs are numbered consecutively and none is empty', () {
    for (final s in content.surahs) {
      for (var i = 0; i < s.ayahs.length; i++) {
        expect(s.ayahs[i].number, i + 1, reason: s.name);
        expect(s.ayahs[i].text.trim(), isNotEmpty, reason: s.name);
      }
    }
  });

  test('al-Ikhlas matches the verified text (letters only)', () {
    String bare(String t) => t
        .replaceAll('\u0671', '\u0627') // ألف الوصل ← ألف
        .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640\\s]'), '');
    final s = content.surahs.firstWhere((s) => s.surahNumber == 112);
    expect(bare(s.ayahs[0].text), bare('قُلْ هُوَ اللَّهُ أَحَدٌ'));
    expect(bare(s.ayahs[1].text), bare('اللَّهُ الصَّمَدُ'));
    expect(bare(s.ayahs[2].text), bare('لَمْ يَلِدْ وَلَمْ يُولَدْ'));
  });

  test('content without a source is rejected', () {
    expect(
      () => QuranRepository.parse('{"source":{"type":"x","name":""},"surahs":[]}'),
      throwsFormatException,
    );
  });
}
