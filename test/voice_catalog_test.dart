import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/cheers.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/data/content/ayah_index.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/features/parent/voice/voice_catalog.dart';

void main() {
  final cat = VoiceCatalog.parse(File(VoiceCatalog.asset).readAsStringSync());
  String key(String t) => VoiceService.clipKey(VoiceService.clean(t));

  test('the catalog has essential phrases, every verified hadith, and the rest', () {
    expect(cat.group('essential').phrases.length, greaterThanOrEqualTo(40));
    expect(cat.group('hadith').phrases.length, greaterThanOrEqualTo(20));
    expect(cat.group('other').phrases.length, greaterThan(500));
    final keys = [for (final g in cat.groups) ...g.phrases.map((p) => p.key)];
    expect(keys.toSet().length, keys.length, reason: 'keys must be unique');
    for (final k in keys) {
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(k), isTrue, reason: k);
    }
  });

  test('catalog keys match the key the app looks up (Dart and Python agree)', () {
    for (final g in cat.groups) {
      for (final p in g.phrases.take(60)) {
        expect(p.key, key(p.text), reason: p.text);
      }
    }
  });

  test('each praise variant is recordable for both girls', () {
    final texts = cat.group('essential').phrases.map((p) => p.text).toSet();
    for (final n in ['فداء', 'نور']) {
      for (final t in [...Cheers.praise, ...Cheers.streak, ...Cheers.tryAgain]) {
        expect(texts, contains(VoiceService.clean(t.replaceAll('{n}', n))), reason: t);
      }
      expect(texts, contains(n));
    }
  });

  test('every hadith lesson line has a recordable hadith entry', () {
    final hadith = {for (final p in cat.group('hadith').phrases) p.key};
    final lessons = ContentRepository.parseLessons(File('assets/content/hadith_lessons.json').readAsStringSync());
    expect(lessons.length, greaterThanOrEqualTo(25));
    for (final l in lessons) {
      expect(hadith, contains(key(l.steps.first.text)), reason: '${l.id} hadith text must be recordable');
    }
  });

  test('ayat and hadith text are never in the machine-voice lists', () {
    final index = AyahIndex.build(
      surahsJson: File('assets/content/quran_surahs.json').readAsStringSync(),
      versesJson: [
        File('assets/content/prophets_ayat.json').readAsStringSync(),
        File('assets/content/section_ayat.json').readAsStringSync(),
      ],
    );
    final hadithKeys = {for (final p in cat.group('hadith').phrases) p.key};
    for (final g in cat.groups.where((g) => g.id != 'hadith')) {
      for (final p in g.phrases) {
        expect(index.of(p.text), isNull, reason: 'ayah in ${g.id}: ${p.text}');
        expect(hadithKeys, isNot(contains(p.key)), reason: 'hadith in ${g.id}');
      }
    }
  });
}
