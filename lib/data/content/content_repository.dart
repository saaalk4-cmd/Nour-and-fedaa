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
    'assets/content/week2_lessons.json',
    'assets/content/week2_early_lessons.json',
    'assets/content/week3_lessons.json',
    'assets/content/week3_early_lessons.json',
    'assets/content/week4_lessons.json',
    'assets/content/week4_early_lessons.json',
    'assets/content/week5_lessons.json',
    'assets/content/week5_early_lessons.json',
    'assets/content/week6_lessons.json',
    'assets/content/week6_early_lessons.json',
    'assets/content/week7_lessons.json',
    'assets/content/week7_early_lessons.json',
    'assets/content/week8_lessons.json',
    'assets/content/week8_early_lessons.json',
    'assets/content/week9_lessons.json',
    'assets/content/week10_lessons.json',
    'assets/content/week11_lessons.json',
    'assets/content/week12_lessons.json',
    'assets/content/week13_lessons.json',
    'assets/content/week14_lessons.json',
    'assets/content/week15_lessons.json',
    'assets/content/week16_lessons.json',
    'assets/content/week17_lessons.json',
    'assets/content/week18_lessons.json',
    'assets/content/week19_lessons.json',
    'assets/content/week20_lessons.json',
    'assets/content/week21_lessons.json',
    'assets/content/week22_lessons.json',
    'assets/content/week23_lessons.json',
    'assets/content/week24_lessons.json',
    'assets/content/week9_early_lessons.json',
    'assets/content/week10_early_lessons.json',
    'assets/content/week11_early_lessons.json',
    'assets/content/week12_early_lessons.json',
    'assets/content/week13_early_lessons.json',
    'assets/content/week14_early_lessons.json',
    'assets/content/week15_early_lessons.json',
    'assets/content/week16_early_lessons.json',
    'assets/content/week17_early_lessons.json',
    'assets/content/week18_early_lessons.json',
    'assets/content/week19_early_lessons.json',
    'assets/content/week20_early_lessons.json',
    'assets/content/week21_early_lessons.json',
    'assets/content/week22_early_lessons.json',
    'assets/content/week23_early_lessons.json',
    'assets/content/week24_early_lessons.json',
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
