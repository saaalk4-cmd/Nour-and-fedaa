import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/lesson.dart';
import '../../domain/level_check.dart';

/// سطر في سجل المصادر الذي يراه ولي الأمر.
class SourceEntry {
  const SourceEntry({
    required this.title,
    required this.sourceTypes,
    required this.sources,
    required this.verified,
    this.note,
    this.audioStatus,
  });

  final String title;
  final Set<String> sourceTypes;
  final Set<String> sources;
  final bool verified;
  final String? note;

  /// حالة الصوت (للدروس فقط).
  final String? audioStatus;
}

const sourceTypeLabels = {
  'quran': 'القرآن الكريم',
  'sahih_sunnah': 'السنة الصحيحة',
  'seerah': 'السيرة',
  'scholars': 'أقوال أهل العلم',
  'educational': 'تعليمي عام',
};

/// يبني سجل مصادر كل محتوى مضمَّن في التطبيق، من ملفات assets نفسها،
/// فلا يمكن أن يختلف السجل عن المحتوى الفعلي.
class ContentCatalog {
  ContentCatalog({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<SourceEntry>> entries() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final assets = manifest.listAssets()..sort();
    final out = <SourceEntry>[];
    for (final a in assets) {
      if (a.startsWith('assets/content/lessons/') && a.endsWith('.json')) {
        final l = Lesson.fromJsonString(await _bundle.loadString(a));
        out.add(SourceEntry(
          title: 'درس: ${l.title}${l.subtitle == null ? '' : ' – ${l.subtitle}'}',
          sourceTypes: {l.sourceType},
          sources: {if (l.sourceNote != null) l.sourceNote!},
          verified: l.contentVerified,
          audioStatus: l.steps.any((s) => s.type == StepType.surah)
              ? 'تلاوة أونلاين للشيخ محمد أيوب (مجمع الملك فهد) • الترخيص مؤكَّد'
              : l.hasAudio
                  ? 'موجود • الترخيص: ${l.audioLicense}'
                  : 'لم يُسجَّل بعد',
        ));
      } else if (a.startsWith('assets/content/levelcheck/') &&
          a.endsWith('.json')) {
        final raw = await _bundle.loadString(a);
        final c = LevelCheck.fromJsonString(raw);
        final verified =
            (jsonDecode(raw) as Map<String, dynamic>)['content_verified'] == true;
        out.add(SourceEntry(
          title: 'اختبار المستوى – ${c.band.label}',
          sourceTypes: {for (final q in c.questions) q.sourceType},
          sources: {
            for (final q in c.questions)
              if (q.source.isNotEmpty) q.source
          },
          verified: verified,
          note: '${c.questions.length} سؤالًا',
        ));
      }
    }
    return out;
  }
}
