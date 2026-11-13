import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'lesson.dart';

/// يحمّل الدروس من ملفات JSON داخل assets (يعمل بدون إنترنت).
/// إضافة درس جديد = إضافة عنصر في الملف، بدون تعديل الكود.
class ContentRepository {
  static const String learnAsset = 'assets/content/learn_lessons.json';

  /// كل ملفات الدروس (أتعلم + تدريب القرآن والأحاديث المولَّد من محتوى موثّق).
  static const List<String> lessonAssets = [
    learnAsset,
    'assets/content/quran_lessons.json',
    'assets/content/hadith_lessons.json',
    'assets/content/prophets_lessons.json',
    'assets/content/week1_lessons.json',
    'assets/content/week1_early_lessons.json',
  ];

  Future<List<Lesson>> loadLessons() async {
    final all = <Lesson>[];
    for (final asset in lessonAssets) {
      all.addAll(parseLessons(await rootBundle.loadString(asset)));
    }
    return all;
  }

  static List<Lesson> parseLessons(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['lessons'] as List<dynamic>)
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
