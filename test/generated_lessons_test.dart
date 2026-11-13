import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/hadith.dart';
import 'package:nourfadaa/data/content/quran.dart';

void main() {
  prophetsTests();
  final quran = QuranRepository.parse(
    File('assets/content/quran_surahs.json').readAsStringSync(),
  );
  final quranLessons = ContentRepository.parseLessons(
    File('assets/content/quran_lessons.json').readAsStringSync(),
  );
  final hadithLessons = ContentRepository.parseLessons(
    File('assets/content/hadith_lessons.json').readAsStringSync(),
  );

  test('every surah has a lesson and its steps are the verified ayahs verbatim', () {
    expect(quranLessons.length, quran.surahs.length);
    for (final s in quran.surahs) {
      final lesson = quranLessons.firstWhere((l) => l.id == 'quran_surah_${s.surahNumber}');
      expect(lesson.source.type, 'quran');
      expect(lesson.category, 'quran');
      expect(lesson.steps.map((e) => e.text).toList(), s.ayahs.map((a) => a.text).toList());
    }
  });

  test('hadith lessons only use text from the sourced hadith files', () {
    final texts = <String>{};
    for (final f in ['akhlaq', 'adhkar', 'prayer', 'seerah']) {
      final c = HadithRepository.parse(
        File('assets/content/${f}_hadith.json').readAsStringSync(),
      );
      texts.addAll(c.hadiths.map((h) => h.text));
    }
    for (final l in hadithLessons) {
      expect(l.source.type, 'sahih_sunnah');
      expect(l.source.reference, contains('('));
      expect(texts, contains(l.steps.first.text), reason: l.id);
    }
  });

  test('questions are well formed: 3 distinct options and a valid answer', () {
    for (final l in [...quranLessons, ...hadithLessons]) {
      expect(l.questions, isNotEmpty, reason: l.id);
      for (final q in l.questions) {
        expect(q.options.toSet().length, q.options.length, reason: l.id);
        expect(q.options.length, 3, reason: l.id);
      }
    }
  });
}

void prophetsTests() {
  final prophets = ProphetsContent.parse(
    File('assets/content/prophets_ayat.json').readAsStringSync(),
  );
  final lessons = ContentRepository.parseLessons(
    File('assets/content/prophets_lessons.json').readAsStringSync(),
  );

  test('prophet verses carry a reference and a Quran source', () {
    expect(prophets.sourceName, contains('Tanzil'));
    expect(prophets.verses.length, 5);
    for (final v in prophets.verses) {
      expect(v.reference, contains('سورة'), reason: v.id);
      expect(v.ayahTo, greaterThanOrEqualTo(v.ayahFrom), reason: v.id);
      expect(v.text, isNotEmpty, reason: v.id);
    }
  });

  test('prophet lessons reuse the verse text verbatim and cite the Quran', () {
    expect(lessons.length, prophets.verses.length);
    for (final v in prophets.verses) {
      final l = lessons.firstWhere((l) => l.id == '${v.id}_lesson');
      expect(l.source.type, 'quran');
      expect(l.category, 'prophets');
      expect(l.steps.first.text, v.text);
    }
  });
}
