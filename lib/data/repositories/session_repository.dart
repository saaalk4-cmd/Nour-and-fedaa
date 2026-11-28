import 'package:flutter/services.dart';

import '../../domain/age_band.dart';
import '../../domain/course_session.dart';

/// منهج السنة لكل فئة: assets/content/sessions/<band>.json. فئة بلا ملف = بلا منهج بعد.
class SessionRepository {
  SessionRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _cache = <AgeBand, List<CourseSession>>{};

  Future<List<CourseSession>> forBand(AgeBand band) async {
    final cached = _cache[band];
    if (cached != null) return cached;
    String raw;
    try {
      raw = await _bundle.loadString('assets/content/sessions/${band.name}.json');
    } catch (_) {
      return _cache[band] = const [];
    }
    return _cache[band] = CourseSession.listFromJsonString(raw);
  }
}
