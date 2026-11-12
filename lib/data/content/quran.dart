import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// آية واحدة (النص مأخوذ حرفيًا من Tanzil ولا يُعدَّل أبدًا).
class Ayah {
  const Ayah({required this.number, required this.text});

  final int number;
  final String text;
}

class Surah {
  const Surah({
    required this.id,
    required this.surahNumber,
    required this.name,
    required this.ayahs,
  });

  final String id;
  final int surahNumber;
  final String name;
  final List<Ayah> ayahs;
}

class QuranContent {
  const QuranContent({
    required this.surahs,
    required this.sourceName,
    required this.sourceUrl,
    required this.license,
  });

  final List<Surah> surahs;
  final String sourceName;
  final String sourceUrl;
  final String license;
}

class QuranRepository {
  static const String asset = 'assets/content/quran_surahs.json';

  Future<QuranContent> load() async => parse(await rootBundle.loadString(asset));

  static QuranContent parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final source = doc['source'] as Map<String, dynamic>;
    // لا نقبل نصًا قرآنيًا بلا مصدر موثّق.
    if (source['type'] != 'quran' || (source['name'] as String?)?.isEmpty != false) {
      throw const FormatException('Quran content must declare its source');
    }
    final surahs = (doc['surahs'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      final ayahs = (m['ayahs'] as List<dynamic>)
          .map((a) => Ayah(
                number: (a as Map<String, dynamic>)['number'] as int,
                text: a['text'] as String,
              ))
          .toList();
      if (ayahs.length != m['ayahCount']) {
        throw FormatException('Ayah count mismatch in ${m['id']}');
      }
      return Surah(
        id: m['id'] as String,
        surahNumber: m['surahNumber'] as int,
        name: m['name'] as String,
        ayahs: ayahs,
      );
    }).toList();
    return QuranContent(
      surahs: surahs,
      sourceName: source['name'] as String,
      sourceUrl: source['url'] as String,
      license: source['license'] as String,
    );
  }
}
