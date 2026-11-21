import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/ayah_index.dart';
import 'package:nourfadaa/data/models/child.dart';
import 'package:nourfadaa/features/online/online_games_screen.dart';

void main() {
  test('the link opens the page on the right girl', () {
    expect(onlineGamesUri(const Child(id: 1, name: 'فداء', age: 5)).queryParameters['child'], 'fedaa');
    expect(onlineGamesUri(const Child(id: 2, name: 'نور', age: 3)).queryParameters['child'], 'nour');
    expect(onlineGamesUri(null).toString(), kOnlineGamesUrl);
    expect(kOnlineGamesUrl, startsWith('https://'));
  });

  final phrases = (jsonDecode(File('games_web/phrases.json').readAsStringSync()) as Map<String, dynamic>);
  final list = (phrases['phrases'] as List<dynamic>).cast<String>().toSet();

  test('every sentence the page says is recorded in the app voice (no device voice needed)', () {
    final js = File('games_web/app.js').readAsStringSync();
    final literals = <String>{
      for (final m in RegExp(r"(?:say|intro:|finishSay:)\s*\(?\s*'([^'$]+)'").allMatches(js)) m.group(1)!,
      for (final m in RegExp(r"'([^'$]*[؀-ۿ][^'$]*)'").allMatches(
          RegExp(r'pick\(\[([^\]]*)\]\)').allMatches(js).map((m) => m.group(1)!).join(' '))) m.group(1)!,
    };
    for (final s in literals) {
      expect(list, contains(s), reason: 'add to games_web/phrases.json: $s');
    }
    for (final n in ['فداء', 'نور']) {
      for (final p in ['أحسنتِ يا $n!', 'رائع يا $n!', 'ممتاز يا $n!', 'أهلًا يا $n! هيا نلعب']) {
        expect(list, contains(p));
      }
    }
    for (final l in phrases['letters'] as List<dynamic>) {
      expect(list, contains((l as Map<String, dynamic>)['word']));
      expect(File('assets/art/${l['art']}.webp').existsSync(), isTrue);
    }
    for (final p in phrases['pics'] as List<dynamic>) {
      expect(list, contains((p as Map<String, dynamic>)['word']));
      expect(File('assets/art/${p['art']}.webp').existsSync(), isTrue);
    }
  });

  test('no ayah is ever spoken by the machine voice on the page', () {
    final ayat = AyahIndex.build(
      surahsJson: File('assets/content/quran_surahs.json').readAsStringSync(),
      versesJson: [
        File('assets/content/prophets_ayat.json').readAsStringSync(),
        File('assets/content/section_ayat.json').readAsStringSync(),
      ],
    );
    for (final s in list) {
      expect(ayat.of(s), isNull, reason: s);
    }
  });
}
