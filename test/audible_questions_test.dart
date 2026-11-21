import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/ayah_index.dart';
import 'package:nourfadaa/data/content/content_repository.dart';

/// كل سؤال مسموع: أي نص آية في السؤال أو الاختيارات له تلاوة مسجّلة يعرفها التطبيق.
void main() {
  final index = AyahIndex.build(
    surahsJson: File('assets/content/quran_surahs.json').readAsStringSync(),
    versesJson: [
      File('assets/content/prophets_ayat.json').readAsStringSync(),
      File('assets/content/section_ayat.json').readAsStringSync(),
    ],
  );
  final lessons = [
    for (final f in Directory('assets/content').listSync().whereType<File>())
      if (f.path.endsWith('_lessons.json')) ...ContentRepository.parseLessons(f.readAsStringSync()),
  ];

  test('the ayah index knows every surah ayah, prophet ayah and section ayah', () {
    expect(index.length, greaterThan(70));
    final q = jsonDecode(File('assets/content/quran_surahs.json').readAsStringSync()) as Map<String, dynamic>;
    final ikhlas = (q['surahs'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['surahNumber'] == 112);
    final first = ((ikhlas['ayahs'] as List).first as Map<String, dynamic>)['text'] as String;
    expect([index.of(first)!.surah, index.of(first)!.ayah], [112, 1]);
    final doc = jsonDecode(File('assets/content/prophets_ayat.json').readAsStringSync()) as Map<String, dynamic>;
    final musaText = (doc['verses'] as List).cast<Map<String, dynamic>>().firstWhere((v) => v['id'] == 'prophet_musa')['text'] as String;
    final musa = index.of(musaText);
    expect([musa!.surah, musa.ayah, musa.toAyah], [20, 25, 26]);
  });

  test('ayah lines inside Quran-lesson questions and options can be recited', () {
    for (final l in lessons.where((l) => l.source.type == 'quran')) {
      final quoted = {if (l.steps.isNotEmpty) l.steps.first.text.trim()};
      for (final q in l.questions) {
        for (final line in [...q.prompt.split('\n'), ...q.options]) {
          final t = line.trim();
          if (!quoted.contains(t) && index.of(t) == null) continue;
          final viaStep = l.steps.any((s) => s.recite != null && s.text.trim() == t);
          final viaSurah = l.id.startsWith('quran_surah_');
          expect(viaStep || viaSurah || index.of(t) != null, isTrue, reason: '${l.id}: "$t" has no recitation');
        }
      }
    }
  });
}
