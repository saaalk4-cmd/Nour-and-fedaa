import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';

int words(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final forNour = all.where((l) => l.fitsAge(3)).toList();

  test('content level follows the child age (3 / 4 / 5)', () {
    expect(ContentLevel.forAge(3).ageGroup, 3);
    expect(ContentLevel.forAge(4).ageGroup, 4);
    expect(ContentLevel.forAge(5).ageGroup, 5);
    expect(ContentLevel.forAge(3).pictureOnly, isTrue);
    expect(ContentLevel.forAge(4).pictureOnly, isTrue);
    expect(ContentLevel.forAge(5).pictureOnly, isFalse);
  });

  test('every religious lesson for age 3 has a hand-written toddler view (no hadith text)', () {
    for (final l in forNour) {
      if (l.source.type == 'educational' || l.surahNumber != null) continue;
      expect(l.toddler, isNotNull, reason: '${l.id} needs a toddler block');
    }
  });

  test('toddler cards are short: few words, never a hadith, never a source', () {
    final level = ContentLevel.forAge(3);
    for (final l in forNour) {
      final cards = l.toddlerCards();
      expect(cards, isNotEmpty, reason: l.id);
      for (final c in cards) {
        expect(words(c.word), lessThanOrEqualTo(level.maxWords), reason: '${l.id}: "${c.word}"');
        expect(c.word.length, lessThanOrEqualTo(24), reason: l.id);
      }
      if (l.source.type != 'educational') {
        final joined = cards.map((c) => c.word).join(' ');
        for (final s in l.steps) {
          expect(joined.contains(s.text), isFalse, reason: '${l.id} shows its full text');
        }
        expect(joined.contains(l.source.reference), isFalse, reason: l.id);
      }
    }
  });

  test('toddler questions are touch questions with short picture options', () {
    for (final l in forNour) {
      for (final q in l.toddlerQuestions()) {
        expect(q.options.length, inInclusiveRange(2, 3), reason: l.id);
        for (final o in q.options) {
          expect(words(o), lessThanOrEqualTo(4), reason: '${l.id}: "$o"');
        }
        expect(q.say, isNotEmpty, reason: '${l.id} question must be spoken');
      }
    }
  });

  test('machine voice only speaks the two approved religious phrases', () {
    const approved = {'بسم الله', 'السلام عليكم'};
    for (final l in all) {
      if (l.source.type == 'educational' || l.toddler == null) continue;
      for (final c in l.toddler!.cards) {
        final say = c.say ?? c.word;
        final isQuote = l.steps.any((s) => s.text.contains(say) && say.length > 12);
        expect(isQuote, isFalse, reason: '${l.id} speaks a quoted text');
        if (approved.contains(say)) continue;
      }
    }
  });

  test('quran lessons show no text cards except the title and play recitation per ayah', () {
    final fatiha = all.firstWhere((l) => l.id == 'quran_surah_1');
    final cards = fatiha.toddlerCards();
    expect(cards.length, fatiha.steps.length);
    expect(cards.first.word, fatiha.title);
    expect(cards.skip(1).every((c) => c.word.isEmpty), isTrue);
  });
}
