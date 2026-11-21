import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/ayah_index.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson_phrases.dart';

/// assets/content/lesson_phrases.json = كل ما يُقال بالصوت داخل الدروس (يولّد له CI مقاطع مسجّلة).
/// لو تغيّر المحتوى: UPDATE_LESSON_PHRASES=1 flutter test test/lesson_phrases_test.dart
void main() {
  const path = 'assets/content/lesson_phrases.json';

  test('lesson_phrases.json matches what the lesson screens say', () {
    final ayat = AyahIndex.build(
      surahsJson: File('assets/content/quran_surahs.json').readAsStringSync(),
      versesJson: [
        File('assets/content/prophets_ayat.json').readAsStringSync(),
        File('assets/content/section_ayat.json').readAsStringSync(),
      ],
    );
    final lessons = [
      for (final a in ContentRepository.lessonAssets) ...ContentRepository.parseLessons(File(a).readAsStringSync()),
    ];
    final want = lessonPhrases(lessons, ayat).toList()..sort();
    // لا آية ولا نص حديث (الخطوة الأولى في الدروس الدينية) أبدًا.
    final quotes = {
      for (final l in lessons)
        if (l.source.type != 'educational' && !l.allowSpeech && l.steps.isNotEmpty) l.steps.first.text.trim(),
    };
    for (final t in want) {
      expect(ayat.of(t), isNull, reason: 'ayah: $t');
      expect(quotes, isNot(contains(t)), reason: 'quote: $t');
    }
    final file = File(path);
    if (Platform.environment['UPDATE_LESSON_PHRASES'] == '1') {
      file.writeAsStringSync('${const JsonEncoder.withIndent(' ').convert({'schema': 1, 'phrases': want})}\n');
    }
    final have = ((jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['phrases'] as List<dynamic>).cast<String>();
    expect(have, want, reason: 'run: UPDATE_LESSON_PHRASES=1 flutter test test/lesson_phrases_test.dart');
    expect(want.length, greaterThan(1000));
  });
}
