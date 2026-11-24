import 'dart:convert';

import 'age_band.dart';
import 'lesson.dart';

/// المسارات التي يحدَّد لها مستوى البداية.
const placementTracks = ['quran', 'salah', 'maa_la_yasa', 'arabic'];

const kMaxStartLevel = 3;

class LevelQuestion {
  const LevelQuestion({
    required this.track,
    required this.level,
    required this.text,
    required this.options,
    required this.answer,
    required this.sourceType,
    required this.source,
  });

  final String track;
  final int level;
  final String text;
  final List<String> options;
  final int answer;
  final String sourceType;
  final String source;

  factory LevelQuestion.fromJson(Map<String, dynamic> j) {
    final options = (j['options'] as List<dynamic>).cast<String>();
    final answer = j['answer'] as int;
    final source = j['source_type'] as String?;
    if (options.length < 2 || answer < 0 || answer >= options.length) {
      throw const FormatException('خيارات أو إجابة غير صالحة');
    }
    if (source == null || !Lesson.sourceTypes.contains(source)) {
      throw FormatException('source_type مفقود أو غير صالح: $source');
    }
    final track = j['track'] as String;
    if (!placementTracks.contains(track)) {
      throw FormatException('مسار غير معروف: $track');
    }
    return LevelQuestion(
      track: track,
      level: j['level'] as int,
      text: j['text'] as String,
      options: options,
      answer: answer,
      sourceType: source,
      source: (j['source'] as String?) ?? '',
    );
  }
}

class LevelCheck {
  const LevelCheck({required this.band, required this.questions});

  final AgeBand band;
  final List<LevelQuestion> questions;

  factory LevelCheck.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final band = AgeBand.byName(j['band'] as String?);
    if (band == null) throw FormatException('فئة غير معروفة: ${j['band']}');
    final qs = (j['questions'] as List<dynamic>)
        .map((e) => LevelQuestion.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    if (qs.isEmpty) throw const FormatException('اختبار بلا أسئلة');
    return LevelCheck(band: band, questions: qs);
  }

  /// مستوى البداية لكل مسار. [answers]: فهرس السؤال في [questions] ← فهرس الخيار.
  /// المستوى = ١ + عدد الإجابات الصحيحة المتتالية من أول مستوى (بحد أقصى ٣).
  /// الأسئلة المتروكة تُحسب خاطئة. لا يُعرض على الطفل أي «درجة».
  Map<String, int> placement(Map<int, int> answers) {
    final result = <String, int>{};
    for (final track in placementTracks) {
      final idx = [
        for (var i = 0; i < questions.length; i++)
          if (questions[i].track == track) i
      ];
      if (idx.isEmpty) continue;
      var level = 1;
      for (final i in idx) {
        if (answers[i] == questions[i].answer) {
          level++;
        } else {
          break;
        }
      }
      result[track] = level > kMaxStartLevel ? kMaxStartLevel : level;
    }
    return result;
  }
}
