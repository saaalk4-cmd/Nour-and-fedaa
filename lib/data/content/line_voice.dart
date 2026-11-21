import 'ayah_index.dart';
import 'lesson.dart';

/// كيف يُسمَع سطر مكتوب في درس؟ (لا يوجد خيار رابع: لا سطر يبقى صامتًا.)
enum LineKind {
  /// آية: يقرؤها الشيخ بتلاوته المسجّلة.
  recite,

  /// كلام تعليمي: يُنطق (حتى لو كان مشكَّلًا).
  speak,

  /// نص حديث: صوت الأهل المسجّل إن وُجد، وإلا عبارة ثابتة. لا نطق آلي له أبدًا.
  hadith,
}

class LineVoice {
  const LineVoice(this.kind, [this.recitation]);

  final LineKind kind;
  final Recitation? recitation;
}

/// تلاوة هذا السطر لو كان نص آية (من خطوات الدرس أو من فهرس القرآن كله).
Recitation? reciteFor(Lesson lesson, String line, AyahIndex index, {int? surah}) {
  final t = line.trim();
  if (t.isEmpty) return null;
  // في الدروس التعليمية نص الخطوة تعليمات (تُنطق) وتلاوتها تأتي بعدها؛ فلا يُعدّ السطر آية.
  final educational = lesson.source.type == 'educational';
  if (!educational) {
    for (final st in lesson.steps) {
      if (st.recite != null && st.text.trim() == t) return st.recite;
    }
  }
  if (surah != null) {
    for (var i = 0; i < lesson.steps.length; i++) {
      if (lesson.steps[i].text.trim() == t) return Recitation(surah, i + 1);
    }
  }
  return index.of(t);
}

LineVoice classifyLine(Lesson lesson, String line, AyahIndex index, {int? surah}) {
  final r = reciteFor(lesson, line, index, surah: surah);
  if (r != null) return LineVoice(LineKind.recite, r);
  if (lesson.isSpeakable(line, step: true)) return const LineVoice(LineKind.speak);
  return const LineVoice(LineKind.hadith);
}
