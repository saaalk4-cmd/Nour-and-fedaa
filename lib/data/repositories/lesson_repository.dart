import 'package:flutter/services.dart';

import '../../domain/lesson.dart';

/// يحمّل الدروس من ملفات JSON في assets/content/lessons.
/// يمكن لاحقًا جلبها من Firebase دون تغيير الواجهة.
class LessonRepository {
  LessonRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, Lesson> _cache = {};

  Future<Lesson> byId(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/content/lessons/$id.json');
    return _cache[id] = Lesson.fromJsonString(raw);
  }
}
