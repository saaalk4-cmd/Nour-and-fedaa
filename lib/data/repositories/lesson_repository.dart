import 'package:flutter/services.dart';

import '../../domain/age_band.dart';
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

  /// دروس القسم للفئة المحددة، مرتبة بالمعرّف.
  Future<List<Lesson>> bySection(String section, AgeBand band) async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/content/lessons/') && a.endsWith('.json'))
        .toList()
      ..sort();
    final out = <Lesson>[];
    for (final p in paths) {
      final id = p.split('/').last.replaceAll('.json', '');
      final l = await byId(id);
      if (l.section == section && l.band == band) out.add(l);
    }
    return out;
  }
}
