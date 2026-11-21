import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// جملة يمكن للأهل تسجيلها بصوتهم. [key] = VoiceService.clipKey للنص (نفس مفتاح الصوت المسجّل مسبقًا).
class VoicePhrase {
  const VoicePhrase({required this.key, required this.text, this.title, this.source, this.narrator});

  final String key;
  final String text;

  /// للأحاديث: عنوان الحديث، وتخريجه (كتاب ورقم ودرجة) ليقرأه الوالد وهو مطمئن للنص.
  final String? title;
  final String? source;
  final String? narrator;

  factory VoicePhrase.fromJson(Map<String, dynamic> j) => VoicePhrase(
        key: j['key'] as String,
        text: j['text'] as String,
        title: j['title'] as String?,
        source: j['source'] as String?,
        narrator: j['narrator'] as String?,
      );
}

class VoiceGroup {
  const VoiceGroup({required this.id, required this.title, required this.phrases});

  final String id;
  final String title;
  final List<VoicePhrase> phrases;
}

class VoiceCatalog {
  const VoiceCatalog(this.groups);

  final List<VoiceGroup> groups;

  static const asset = 'assets/content/voice_phrases.json';

  static VoiceCatalog parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    return VoiceCatalog([
      for (final g in (doc['groups'] as List).cast<Map<String, dynamic>>())
        VoiceGroup(
          id: g['id'] as String,
          title: g['title'] as String,
          phrases: [for (final p in (g['phrases'] as List).cast<Map<String, dynamic>>()) VoicePhrase.fromJson(p)],
        ),
    ]);
  }

  VoiceGroup group(String id) => groups.firstWhere((g) => g.id == id);

  /// مفتاح ← نص (للنسخة الاحتياطية).
  Map<String, String> get labels => {
        for (final g in groups)
          for (final p in g.phrases) p.key: p.text,
      };
}

final voiceCatalogProvider = FutureProvider<VoiceCatalog>(
  (ref) async => VoiceCatalog.parse(await rootBundle.loadString(VoiceCatalog.asset)),
);
