import 'package:flutter/services.dart';

import '../../domain/hadith.dart';

class HadithRepository {
  HadithRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, Hadith> _cache = {};

  Future<Hadith> byId(String id) async =>
      _cache[id] ??= Hadith.fromJsonString(
          await _bundle.loadString('assets/content/hadith/$id.json'));
}
