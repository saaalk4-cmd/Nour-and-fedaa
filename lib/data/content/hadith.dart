import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// حديث بمصدره كاملًا: لا يُقبل حديث ينقصه الراوي أو الكتاب أو الرقم أو الدرجة.
class Hadith {
  const Hadith({
    required this.id,
    required this.title,
    required this.emoji,
    required this.text,
    required this.narrator,
    required this.book,
    required this.number,
    required this.grade,
    required this.url,
    required this.kidMeaning,
  });

  final String id;
  final String title;
  final String emoji;
  final String text;
  final String narrator;
  final String book;
  final String number;
  final String grade;
  final String url;

  /// معنى مبسّط تعليمي (ليس من نص الحديث).
  final String kidMeaning;

  factory Hadith.fromJson(Map<String, dynamic> j) {
    String req(String k) {
      final v = (j[k] as String?)?.trim() ?? '';
      if (v.isEmpty) {
        throw FormatException('Hadith ${j['id']} is missing "$k"');
      }
      return v;
    }

    return Hadith(
      id: req('id'),
      title: req('title'),
      emoji: req('emoji'),
      text: req('text'),
      narrator: req('narrator'),
      book: req('book'),
      number: req('number'),
      grade: req('grade'),
      url: req('url'),
      kidMeaning: req('kidMeaning'),
    );
  }
}

class HadithContent {
  const HadithContent({required this.hadiths, required this.sourceName});

  final List<Hadith> hadiths;
  final String sourceName;
}

class HadithRepository {
  Future<HadithContent> load(String asset) async =>
      parse(await rootBundle.loadString(asset));

  static HadithContent parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final source = doc['source'] as Map<String, dynamic>;
    if (source['type'] != 'sahih_sunnah' || (source['name'] as String?)?.isEmpty != false) {
      throw const FormatException('Hadith content must declare its source');
    }
    return HadithContent(
      hadiths: (doc['hadiths'] as List<dynamic>)
          .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceName: source['name'] as String,
    );
  }
}
