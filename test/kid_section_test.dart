import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/features/lessons/kid_section_screen.dart';

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final forFedaa = all.where((l) => l.fitsAge(5)).toList();

  test('spokenTitle strips emoji and keeps the words', () {
    expect(spokenTitle('الرحمة 💛'), 'الرحمة');
    expect(spokenTitle('أصبر قليلًا ⏳'), 'أصبر قليلًا');
  });

  test('every religious section has cards for Fedaa', () {
    for (final c in ['quran', 'prayer', 'adhkar', 'akhlaq', 'seerah', 'figures', 'prophets', 'learn']) {
      expect(forFedaa.where((l) => l.category == c), isNotEmpty, reason: c);
    }
  });

  test('learn lessons group into week folders of a few cards each', () {
    final learn = forFedaa.where((l) => l.category == 'learn').toList();
    final groups = <int, int>{};
    for (final l in learn) {
      groups[weekOf(l)] = (groups[weekOf(l)] ?? 0) + 1;
    }
    expect(groups.length, greaterThanOrEqualTo(20));
    expect(groups.values.every((n) => n <= 20), isTrue);
  });

  test('card titles are short and are never the quoted ayah/hadith text', () {
    for (final l in forFedaa) {
      final t = spokenTitle(l.title);
      expect(t, isNotEmpty, reason: l.id);
      expect(t.split(RegExp(r'\s+')).length, lessThanOrEqualTo(6), reason: '${l.id}: $t');
      if (l.steps.isNotEmpty) expect(t, isNot(l.steps.first.text.trim()), reason: l.id);
      // العنوان المنطوق لا يمرّ إلا عبر حارس النطق.
      final say = l.spokenText(t, step: true);
      expect(say, isNotNull, reason: l.id);
    }
  });

  test('every question in every Fedaa lesson can be spoken (no silent screens)', () {
    for (final l in forFedaa) {
      for (final q in l.questions) {
        expect(l.spokenText(q.prompt, say: q.say, step: true), isNotNull, reason: '${l.id}: ${q.prompt}');
      }
    }
  });

  test('the quoted text itself is still never speakable', () {
    for (final l in forFedaa.where((l) => !l.canSpeak && l.steps.isNotEmpty)) {
      expect(l.isSpeakable(l.steps.first.text, step: true), isFalse, reason: l.id);
    }
  });
}
