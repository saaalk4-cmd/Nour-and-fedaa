import '../../core/audio/voice_service.dart' show VoiceService;
import '../../features/lessons/kid_section_screen.dart' show spokenTitle;
import 'ayah_index.dart';
import 'emoji_words.dart';
import 'lesson.dart';
import 'line_voice.dart';

/// كل جملة يقولها التطبيق بالصوت داخل الدروس (للبنتين)، بنفس منطق شاشتي الدرس:
/// - فداء (`lesson_screen.dart`): اسم الدرس، سطور الشرح، السؤال سطرًا سطرًا، كل اختيار، التلميح، المديح.
/// - نور (`toddler_lesson_screen.dart`): اسم الدرس، البطاقات، السؤال، كل اختيار.
/// لا يدخل هنا أبدًا سطر آية (يقرؤه الشيخ) أو نص حديث (صوت الأهل): فقط ما يصنّفه [classifyLine] «كلامًا».
/// الناتج يُحفظ في assets/content/lesson_phrases.json ليولّد له tools/build_voice.py مقاطع مسجّلة،
/// فلا تعتمد البنتان على صوت الموبايل العربي (قد لا يكون موجودًا).
Set<String> lessonPhrases(List<Lesson> lessons, AyahIndex ayat) {
  final out = <String>{};

  void add(String? t) {
    if (t == null) return;
    final c = VoiceService.clean(t);
    // عربي أو أرقام (إجابات الحساب «4» و«12» تُقال أيضًا).
    if (c.isNotEmpty && RegExp('[؀-ۿ0-9]').hasMatch(c)) out.add(c);
  }

  bool speak(Lesson l, String line) =>
      classifyLine(l, line, ayat, surah: l.surahNumber).kind == LineKind.speak;

  for (final l in lessons) {
    add(l.spokenText(spokenTitle(l.title), step: true));

    // ---- فداء (5 سنوات فأكثر) ----
    if (l.maxAge >= 5 && l.surahNumber == null) {
      for (final st in l.steps) {
        final t = l.spokenText(st.text, say: st.say, step: true);
        if (t == null) continue;
        for (final line in t.split('\n')) {
          if (line.trim().isNotEmpty && (st.say != null || speak(l, line.trim()))) add(line.trim());
        }
      }
    }
    if (l.maxAge >= 5) {
      for (final q in l.questions) {
        if (q.recite != null) {
          add(l.spokenText(q.prompt, say: q.say, step: true));
        } else if (q.say != null && q.say!.trim().isNotEmpty) {
          add(q.say);
        } else {
          for (final line in q.prompt.split('\n')) {
            if (line.trim().isNotEmpty && speak(l, line.trim())) add(line.trim());
          }
        }
        final opts = q.isMatch ? [...q.matchLeft, ...q.matchRight] : q.options;
        for (final o in opts) {
          final w = emojiWord(o);
          if (w != null) {
            add(w);
          } else if (speak(l, o)) {
            add(o);
          }
        }
        add(l.spokenText(q.hint, step: true));
        if (q.praise != null) add(l.spokenText(q.praise!, step: true));
      }
    }

    // ---- نور (3–4 سنوات) ----
    if (l.minAge <= 4 && l.surahNumber == null) {
      for (final c in l.toddlerCards()) {
        final t = c.recite != null ? c.say : (c.say ?? c.word);
        if (t != null && speak(l, t)) add(t);
      }
      for (final q in l.toddlerQuestions()) {
        add(q.say ?? q.prompt);
        for (final o in q.options) {
          final w = emojiWord(o);
          if (w != null) {
            add(w);
          } else if (speak(l, o)) {
            add(o);
          }
        }
      }
    }
  }
  return out;
}
