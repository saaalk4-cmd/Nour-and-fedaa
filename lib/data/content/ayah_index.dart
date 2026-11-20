import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'lesson.dart';

/// فهرس نص الآية → تلاوتها المسجّلة، من كل ملفات القرآن في التطبيق.
/// يجعل أي سؤال أو اختيار فيه نص آية مسموعًا بصوت الشيخ (لا نطق آلي للآية أبدًا).
class AyahIndex {
  const AyahIndex(this._map);

  final Map<String, Recitation> _map;

  static const empty = AyahIndex(<String, Recitation>{});

  Recitation? of(String text) => _map[text.trim()];

  int get length => _map.length;

  /// يبني الفهرس من نصوص JSON (منفصل عن التحميل ليُختبر).
  static AyahIndex build({String? surahsJson, List<String> versesJson = const []}) {
    final m = <String, Recitation>{};
    if (surahsJson != null) {
      final doc = jsonDecode(surahsJson) as Map<String, dynamic>;
      for (final s in (doc['surahs'] as List).cast<Map<String, dynamic>>()) {
        final n = s['surahNumber'] as int;
        for (final a in (s['ayahs'] as List).cast<Map<String, dynamic>>()) {
          m[(a['text'] as String).trim()] = Recitation(n, a['number'] as int);
        }
      }
    }
    for (final raw in versesJson) {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      for (final v in (doc['verses'] as List).cast<Map<String, dynamic>>()) {
        m[(v['text'] as String).trim()] =
            Recitation(v['surahNumber'] as int, v['ayahFrom'] as int, v['ayahTo'] as int);
      }
    }
    return AyahIndex(m);
  }

  static Future<AyahIndex> load() async {
    Future<String?> read(String p) async {
      try {
        return await rootBundle.loadString(p);
      } catch (_) {
        return null;
      }
    }

    final verses = <String>[];
    for (final p in const ['assets/content/prophets_ayat.json', 'assets/content/section_ayat.json']) {
      final r = await read(p);
      if (r != null) verses.add(r);
    }
    return build(surahsJson: await read('assets/content/quran_surahs.json'), versesJson: verses);
  }
}
