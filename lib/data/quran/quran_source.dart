import 'dart:convert';

import 'package:http/http.dart' as http;

/// آية واحدة: نصها كما في المصدر ورابط تلاوتها.
class Ayah {
  const Ayah({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.audioUrl,
  });

  /// رقم الآية في المصحف كله (١–٦٢٣٦).
  final int number;
  final int numberInSurah;
  final String text;
  final String audioUrl;
}

class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.ayahs,
    this.basmala,
  });

  final int number;
  final String name;
  final List<Ayah> ayahs;

  /// البسملة تُعرض وتُتلى قبل السورة (غير الفاتحة والتوبة)، بلا رقم.
  final Ayah? basmala;
}

class QuranDataException implements Exception {
  const QuranDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// مصدر نص القرآن وتلاوته (أونلاين).
abstract class QuranSource {
  Future<Surah> surah(int number);
}

/// عدد آيات السور المستخدمة في التطبيق (رواية حفص)، للتحقق من سلامة ما يصل.
/// لا تُضاف سورة إلى الدروس قبل إضافة عددها هنا.
const kKnownAyahCounts = {
  1: 7,
  87: 19,
  90: 20,
  91: 15,
  93: 11,
  94: 8,
  95: 8,
  97: 5,
  99: 8,
  100: 11,
  102: 8,
  103: 3,
  106: 4,
  108: 3,
  110: 3,
  112: 4,
  113: 5,
  114: 6,
};

const kQuranTextAttribution = 'نص المصحف: مشروع تنزيل (Tanzil) عبر AlQuran Cloud';
const kQuranAudioAttribution = 'التلاوة: الشيخ محمد صديق المنشاوي (مرتّل)';

/// AlQuran Cloud: النص العثماني من مشروع تنزيل، وتلاوة المنشاوي لكل آية.
class AlQuranCloudSource implements QuranSource {
  AlQuranCloudSource({http.Client? client, this.reciter = 'ar.minshawi'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String reciter;
  final Map<int, Surah> _cache = {};

  static const _base = 'https://api.alquran.cloud/v1/surah';

  Future<List<Map<String, dynamic>>> _editions(int n) async {
    final res = await _client
        .get(Uri.parse('$_base/$n/editions/quran-uthmani,$reciter'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw QuranDataException('تعذّر تحميل السورة (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['data'] as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Surah> surah(int number) async {
    final cached = _cache[number];
    if (cached != null) return cached;
    final parsed = parseSurah(number, await _editions(number),
        fatiha: number == 1 || number == 9 ? null : await _fatihaEditions());
    return _cache[number] = parsed;
  }

  List<Map<String, dynamic>>? _fatiha;
  Future<List<Map<String, dynamic>>> _fatihaEditions() async =>
      _fatiha ??= await _editions(1);
}

String _clean(String s) => s.replaceAll('﻿', '').trim();

/// يحوّل استجابة المصدر إلى سورة بعد التحقق منها. [fatiha]: بيانات الفاتحة
/// لأخذ نص البسملة وتلاوتها من المصدر نفسه (لا يُكتب نص قرآني يدويًا).
Surah parseSurah(
  int number,
  List<Map<String, dynamic>> editions, {
  List<Map<String, dynamic>>? fatiha,
}) {
  Map<String, dynamic> byFormat(List<Map<String, dynamic>> eds, String f) =>
      eds.firstWhere(
        (e) => (e['edition'] as Map)['format'] == f,
        orElse: () => throw const QuranDataException('بيانات السورة ناقصة'),
      );
  final text = byFormat(editions, 'text');
  final audio = byFormat(editions, 'audio');
  final tAyahs = (text['ayahs'] as List).cast<Map<String, dynamic>>();
  final aAyahs = (audio['ayahs'] as List).cast<Map<String, dynamic>>();

  final expected = kKnownAyahCounts[number];
  if (text['number'] != number ||
      text['numberOfAyahs'] != tAyahs.length ||
      tAyahs.length != aAyahs.length ||
      (expected != null && tAyahs.length != expected)) {
    throw QuranDataException('فشل التحقق من عدد آيات السورة $number');
  }

  String? basmalaText;
  Ayah? basmala;
  if (fatiha != null) {
    final ft = byFormat(fatiha, 'text');
    final fa = byFormat(fatiha, 'audio');
    final b = (ft['ayahs'] as List).first as Map<String, dynamic>;
    final ba = (fa['ayahs'] as List).first as Map<String, dynamic>;
    basmalaText = _clean(b['text'] as String);
    basmala = Ayah(
      number: b['number'] as int,
      numberInSurah: 0,
      text: basmalaText,
      audioUrl: ba['audio'] as String,
    );
  }

  final ayahs = <Ayah>[];
  for (var i = 0; i < tAyahs.length; i++) {
    final t = tAyahs[i];
    final a = aAyahs[i];
    if (t['number'] != a['number'] || t['numberInSurah'] != i + 1) {
      throw QuranDataException('ترتيب آيات السورة $number غير متطابق');
    }
    var s = _clean(t['text'] as String);
    if (i == 0 && basmalaText != null && s.startsWith('$basmalaText ')) {
      s = s.substring(basmalaText.length + 1);
    }
    ayahs.add(Ayah(
      number: t['number'] as int,
      numberInSurah: i + 1,
      text: s,
      audioUrl: a['audio'] as String,
    ));
  }
  return Surah(
    number: number,
    name: _clean(text['name'] as String),
    ayahs: ayahs,
    basmala: basmala,
  );
}
