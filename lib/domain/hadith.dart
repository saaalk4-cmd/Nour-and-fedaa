import 'dart:convert';

import 'arabic_digits.dart';

/// حديث محفوظ نصّه في التطبيق كما نُسخ من مصدره، مع رابط المصدر للأهل.
class Hadith {
  const Hadith({
    required this.id,
    required this.collection,
    required this.number,
    required this.narrator,
    required this.matn,
    required this.url,
    this.isnad,
    this.grade,
  });

  final String id;
  final String collection;
  final int number;
  final String narrator;
  final String matn;
  final String url;
  final String? isnad;
  final String? grade;

  /// مثل: «صحيح البخاري ٦٢٢٤».
  String get reference => '$collection ${toArabicDigits(number)}';

  factory Hadith.fromJson(Map<String, dynamic> j) {
    final url = j['url'] as String?;
    final matn = j['matn'] as String?;
    if (url == null || !url.startsWith('https://')) {
      throw const FormatException('الحديث بلا رابط مصدر');
    }
    if (matn == null || matn.trim().isEmpty) {
      throw const FormatException('الحديث بلا نص');
    }
    return Hadith(
      id: j['id'] as String,
      collection: j['collection'] as String,
      number: j['number'] as int,
      narrator: j['narrator'] as String,
      matn: matn,
      url: url,
      isnad: j['isnad'] as String?,
      grade: j['grade'] as String?,
    );
  }

  factory Hadith.fromJsonString(String s) =>
      Hadith.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
