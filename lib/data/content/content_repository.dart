import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'lesson.dart';

/// يحمّل الدروس من ملفات JSON داخل assets (يعمل بدون إنترنت).
/// إضافة درس جديد = إضافة عنصر في الملف، بدون تعديل الكود.
class ContentRepository {
  static const String learnAsset = 'assets/content/learn_lessons.json';

  Future<List<Lesson>> loadLessons() async {
    final raw = await rootBundle.loadString(learnAsset);
    return parseLessons(raw);
  }

  static List<Lesson> parseLessons(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['lessons'] as List<dynamic>)
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
