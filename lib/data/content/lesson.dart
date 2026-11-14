/// مصدر المحتوى. إلزامي لكل درس: لا يُقبل درس بلا مصدر.
class ContentSource {
  const ContentSource({required this.type, required this.reference});

  static const Set<String> allowedTypes = {
    'quran',
    'sahih_sunnah',
    'seerah',
    'scholars',
    'educational',
  };

  final String type;
  final String reference;

  factory ContentSource.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('الدرس بلا مصدر (source)');
    }
    final type = json['type'];
    final reference = json['reference'];
    if (type is! String || !allowedTypes.contains(type)) {
      throw FormatException('نوع المصدر غير صالح: $type');
    }
    if (reference is! String || reference.trim().isEmpty) {
      throw const FormatException('مرجع المصدر فارغ');
    }
    return ContentSource(type: type, reference: reference);
  }
}

class LessonStep {
  const LessonStep({required this.emoji, required this.text, this.say});

  final String emoji;
  final String text;

  /// نص يُقرأ بصوت عالٍ بدل النص المكتوب (اختياري).
  final String? say;

  factory LessonStep.fromJson(Map<String, dynamic> json) => LessonStep(
        emoji: json['emoji'] as String,
        text: json['text'] as String,
        say: json['say'] as String?,
      );
}

class LessonQuestion {
  const LessonQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.hint,
    this.emoji,
    this.praise,
    this.say,
  });

  final String prompt;
  final String? emoji;
  final List<String> options;
  final int answerIndex;
  final String hint;

  /// جملة تشجيع خاصة تظهر بعد الإجابة الصحيحة (اختيارية).
  final String? praise;

  /// ما يُقرأ بصوت عالٍ للسؤال (يشمل الخيارات إن لزم). الافتراضي: نص السؤال.
  final String? say;

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>).cast<String>();
    final answer = json['answerIndex'] as int;
    if (options.length < 2 || answer < 0 || answer >= options.length) {
      throw FormatException('سؤال غير صالح: ${json['prompt']}');
    }
    return LessonQuestion(
      prompt: json['prompt'] as String,
      emoji: json['emoji'] as String?,
      options: options,
      answerIndex: answer,
      hint: json['hint'] as String,
      praise: json['praise'] as String?,
      say: json['say'] as String?,
    );
  }
}

/// بطاقة واحدة في واجهة الصغيرات: صورة كبيرة + كلمة قصيرة جدًا + صوت.
/// تُكتب يدويًا (أو تُشتق من خطوات قصيرة) ولا تحتوي نص حديث أو مرجعًا أبدًا.
class ToddlerCard {
  const ToddlerCard({required this.emoji, required this.word, this.say});

  final String emoji;

  /// كلمة أو جملة قصيرة تظهر بخط كبير (قد تكون فارغة).
  final String word;

  /// ما يُنطق عند الضغط على 🔊 (الافتراضي: الكلمة).
  final String? say;

  factory ToddlerCard.fromJson(Map<String, dynamic> json) => ToddlerCard(
        emoji: json['emoji'] as String,
        word: json['word'] as String,
        say: json['say'] as String?,
      );
}

/// واجهة الأطفال بعمر 3–4: بطاقات + نشاط لمس واحد (اختياري). المصدر والنص الكامل للوالدين فقط.
class ToddlerView {
  const ToddlerView({required this.cards, this.question});

  final List<ToddlerCard> cards;
  final LessonQuestion? question;

  factory ToddlerView.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>)
        .map((e) => ToddlerCard.fromJson(e as Map<String, dynamic>))
        .toList();
    if (cards.isEmpty) throw const FormatException('toddler بلا بطاقات');
    final q = json['question'];
    return ToddlerView(
      cards: cards,
      question: q == null ? null : LessonQuestion.fromJson(q as Map<String, dynamic>),
    );
  }
}

/// مستوى المحتوى حسب العمر (ageGroup 3 / 4 / 5): يحدد شكل الدرس تلقائيًا.
class ContentLevel {
  const ContentLevel._(this.ageGroup);

  /// 3 = نور (صور وصوت ولمس)، 4 = مثلها مع كلمات أكثر، 5 فأكثر = فداء (كلمات وجمل وأسئلة).
  final int ageGroup;

  factory ContentLevel.forAge(int age) =>
      ContentLevel._(age <= 3 ? 3 : (age == 4 ? 4 : 5));

  /// واجهة بلا قراءة: صورة + صوت + كلمة قصيرة + لمس.
  bool get pictureOnly => ageGroup <= 4;

  /// أقصى عدد كلمات للبطاقة الواحدة.
  int get maxWords => ageGroup == 3 ? 3 : 5;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    required this.minAge,
    required this.maxAge,
    required this.difficulty,
    required this.steps,
    required this.questions,
    required this.source,
    this.objective,
    this.learned,
    this.allowSpeech = false,
    this.toddler,
  });

  final String id;
  final String title;
  final String emoji;
  final String category;
  final int minAge;
  final int maxAge;
  final int difficulty;
  final List<LessonStep> steps;
  final List<LessonQuestion> questions;
  final ContentSource source;

  /// هدف الدرس (للوالدين) و«ماذا تعلمت؟» (تظهر للطفلة بعد الإكمال). اختياريان.
  final String? objective;
  final String? learned;

  /// يسمح بالنطق الآلي لدرس مصدره ديني (عبارة قصيرة معتمدة فقط). الافتراضي: ممنوع.
  final bool allowSpeech;

  /// واجهة الصغيرات المكتوبة يدويًا (إلزامية للدروس الدينية غير القرآنية).
  final ToddlerView? toddler;

  /// سور القرآن: رقم السورة من المعرّف quran_surah_N.
  int? get surahNumber {
    final m = RegExp(r'^quran_surah_(\d+)$').firstMatch(id);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// بطاقات الصغيرات: المكتوبة، أو (للقرآن) بطاقة لكل آية بلا نص، أو (للتعليمي) من الخطوات القصيرة.
  /// الدرس الديني بلا toddler لا يُظهر نصه أبدًا: بطاقة واحدة بعنوانه فقط.
  List<ToddlerCard> toddlerCards() {
    final t = toddler;
    if (t != null) return t.cards;
    if (surahNumber != null) {
      return [
        for (var i = 0; i < steps.length; i++)
          ToddlerCard(emoji: i == 0 ? emoji : '🎧', word: i == 0 ? title : ''),
      ];
    }
    if (source.type == 'educational') {
      return [
        for (final s in steps)
          ToddlerCard(
            emoji: s.emoji,
            word: s.text.length <= 24 ? s.text : '',
            say: s.say ?? s.text,
          ),
      ];
    }
    return [ToddlerCard(emoji: emoji, word: title)];
  }

  /// أسئلة الصغيرات: السؤال المكتوب يدويًا، أو أسئلة الدرس التعليمي نفسها، ولا شيء غير ذلك.
  List<LessonQuestion> toddlerQuestions() {
    final t = toddler;
    if (t != null) return t.question == null ? const [] : [t.question!];
    if (source.type == 'educational') return questions;
    return const [];
  }

  /// هل يجوز النطق الآلي لهذا الدرس؟ المحتوى التعليمي فقط (أو المسموح صراحة).
  bool get canSpeak => source.type == 'educational' || allowSpeech;

  bool fitsAge(int age) => age >= minAge && age <= maxAge;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>)
        .map((e) => LessonStep.fromJson(e as Map<String, dynamic>))
        .toList();
    final questions = (json['questions'] as List<dynamic>)
        .map((e) => LessonQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    if (steps.isEmpty) {
      throw FormatException('الدرس ${json['id']} بلا خطوات');
    }
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String,
      category: json['category'] as String,
      minAge: json['minAge'] as int,
      maxAge: json['maxAge'] as int,
      difficulty: json['difficulty'] as int,
      steps: steps,
      questions: questions,
      source: ContentSource.fromJson(json['source']),
      objective: json['objective'] as String?,
      learned: json['learned'] as String?,
      allowSpeech: json['allowSpeech'] == true,
      toddler: json['toddler'] == null
          ? null
          : ToddlerView.fromJson(json['toddler'] as Map<String, dynamic>),
    );
  }
}
