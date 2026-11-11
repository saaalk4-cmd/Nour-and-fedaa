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
  const LessonStep({required this.emoji, required this.text});

  final String emoji;
  final String text;

  factory LessonStep.fromJson(Map<String, dynamic> json) => LessonStep(
        emoji: json['emoji'] as String,
        text: json['text'] as String,
      );
}

class LessonQuestion {
  const LessonQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.hint,
    this.emoji,
  });

  final String prompt;
  final String? emoji;
  final List<String> options;
  final int answerIndex;
  final String hint;

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
    );
  }
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
    );
  }
}
