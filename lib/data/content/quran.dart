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

/// آية (أو آيتان) من قصص الأنبياء مع مرجعها (سورة:آية) ومعنى مبسّط من مضمونها.
class ProphetVerse {
  const ProphetVerse({
    required this.id,
    required this.prophet,
    required this.title,
    required this.emoji,
    required this.surahName,
    required this.ayahFrom,
    required this.ayahTo,
    required this.text,
    required this.kidMeaning,
  });

  final String id;
  final String prophet;
  final String title;
  final String emoji;
  final String surahName;
  final int ayahFrom;
  final int ayahTo;
  final String text;
  final String kidMeaning;

  String get reference => ayahFrom == ayahTo
      ? 'سورة $surahName، آية $ayahFrom'
      : 'سورة $surahName، الآيات $ayahFrom–$ayahTo';

  factory ProphetVerse.fromJson(Map<String, dynamic> j) {
    String req(String k) {
      final v = (j[k] as String?)?.trim() ?? '';
      if (v.isEmpty) throw FormatException('Prophet verse ${j['id']} is missing "$k"');
      return v;
    }

    return ProphetVerse(
      id: req('id'),
      prophet: req('prophet'),
      title: req('title'),
      emoji: req('emoji'),
      surahName: req('surahName'),
      ayahFrom: j['ayahFrom'] as int,
      ayahTo: j['ayahTo'] as int,
      text: req('text'),
      kidMeaning: req('kidMeaning'),
    );
  }
}

class ProphetsContent {
  const ProphetsContent({required this.verses, required this.sourceName});

  final List<ProphetVerse> verses;
  final String sourceName;

  static ProphetsContent parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final source = doc['source'] as Map<String, dynamic>;
    if (source['type'] != 'quran' || (source['name'] as String?)?.isEmpty != false) {
      throw const FormatException('Prophets content must declare its Quran source');
    }
    return ProphetsContent(
      verses: (doc['verses'] as List<dynamic>)
          .map((e) => ProphetVerse.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceName: source['name'] as String,
    );
  }
}
