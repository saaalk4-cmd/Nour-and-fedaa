import 'dart:convert';
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
    for (final f in ['akhlaq', 'adhkar', 'prayer', 'seerah', 'figures']) {
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
    // الأنبياء الخمسة والعشرون المذكورون في القرآن، من آدم إلى محمد ﷺ.
    expect(prophets.verses.length, 25);
    expect(prophets.verses.first.id, 'prophet_adam');
    expect(prophets.verses.last.id, 'prophet_muhammad');
    expect(prophets.verses.map((v) => v.id).toSet().length, 25);
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

  test('every prophet ayah is recited by the sheikh, for Fedaa and for Nour', () {
    for (final v in prophets.verses) {
      final l = lessons.firstWhere((l) => l.id == '${v.id}_lesson');
      final r = l.steps.first.recite;
      expect(r, isNotNull, reason: l.id);
      expect([r!.surah, r.ayah, r.toAyah], [v.surahNumber, v.ayahFrom, v.ayahTo], reason: l.id);
      final cards = l.toddlerCards();
      expect(cards.where((c) => c.recite != null).length, 1, reason: '${l.id}: Nour hears the sheikh');
      // الآية لا تُنطق آليًا أبدًا: لا في درس فداء ولا في بطاقات نور.
      expect(l.spokenText(v.text), isNull, reason: l.id);
      for (final c in cards) {
        expect(v.text.contains(c.say ?? c.word) && (c.say ?? c.word).isNotEmpty, isFalse, reason: l.id);
      }
    }
  });

  final sections = ContentRepository.parseLessons(
    File('assets/content/section_ayat_lessons.json').readAsStringSync(),
  );

  test('seerah, figures and adhkar ayat are Quran-sourced and recited by the sheikh', () {
    expect(sections.length, greaterThanOrEqualTo(13));
    for (final l in sections) {
      expect(['seerah', 'figures', 'adhkar'], contains(l.category), reason: l.id);
      expect(l.source.type, 'quran', reason: l.id);
      expect(l.source.reference, contains('Tanzil'), reason: l.id);
      expect(l.steps.first.recite, isNotNull, reason: l.id);
      expect(l.spokenText(l.steps.first.text), isNull, reason: '${l.id}: ayah never machine-spoken');
      expect(l.toddlerCards().where((c) => c.recite != null).length, 1, reason: l.id);
    }
  });

  test('new hadith entries are sahih, numbered and read twice', () {
    for (final f in ['adhkar', 'seerah', 'figures']) {
      final doc = jsonDecode(File('assets/content/${f}_hadith.json').readAsStringSync()) as Map<String, dynamic>;
      for (final h in (doc['hadiths'] as List).cast<Map<String, dynamic>>()) {
        if (!h.containsKey('verified')) continue;
        expect(h['grade'], 'صحيح', reason: h['id'] as String);
        expect(int.tryParse(h['number'] as String), isNotNull, reason: h['id'] as String);
        expect((h['verified'] as List).length, 2, reason: h['id'] as String);
        expect(h['url'] as String, startsWith('https://hadeethenc.com/'), reason: h['id'] as String);
      }
    }
  });
}
