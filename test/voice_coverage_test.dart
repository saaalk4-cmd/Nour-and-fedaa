import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/ayah_index.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/data/content/line_voice.dart';

/// لا سطر مكتوب في أي درس يبقى بلا صوت: آية ← الشيخ، حديث ← صوت الأهل (أو عبارة ثابتة)،
/// وغير ذلك ← يُنطق (حتى لو كان مشكَّلًا). ولا آية أو حديث يُنطق آليًا أبدًا.
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
  int? surahOf(Lesson l) {
    final m = RegExp(r'^quran_surah_(\d+)$').firstMatch(l.id);
    return m == null ? null : int.parse(m.group(1)!);
  }

  Iterable<String> lines(Lesson l) sync* {
    for (final s in l.steps) {
      yield* s.text.split('\n');
    }
    for (final q in l.questions) {
      yield* q.prompt.split('\n');
      yield* q.options;
    }
  }

  test('every line of every lesson has a way to be heard', () {
    var n = 0;
    for (final l in lessons) {
      for (final raw in lines(l)) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        n++;
        final c = classifyLine(l, t, index, surah: surahOf(l));
        expect(LineKind.values, contains(c.kind), reason: '${l.id}: $t');
        if (c.kind == LineKind.recite) expect(c.recitation, isNotNull, reason: '${l.id}: $t');
      }
    }
    expect(n, greaterThan(3000));
  });

  test('educational lines are always spoken; Quran lines are always recited by the sheikh', () {
    for (final l in lessons) {
      for (final raw in lines(l)) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final c = classifyLine(l, t, index, surah: surahOf(l));
        if (l.source.type == 'educational') {
          expect(c.kind, LineKind.speak, reason: '${l.id}: "$t" must be spoken');
        }
        if (index.of(t) != null) {
          expect(c.kind, LineKind.recite, reason: '${l.id}: ayah "$t" must be recited, not spoken');
        }
        if (l.source.type == 'quran') {
          expect(c.kind, isNot(LineKind.hadith), reason: '${l.id}: "$t" is a Quran lesson line');
        }
      }
    }
  });

  test('only hadith lessons ever fall back to the hadith placeholder', () {
    for (final l in lessons) {
      for (final raw in lines(l)) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final c = classifyLine(l, t, index, surah: surahOf(l));
        if (c.kind == LineKind.hadith) {
          expect(l.source.type, 'sahih_sunnah', reason: '${l.id}: "$t"');
        }
      }
    }
  });
}
