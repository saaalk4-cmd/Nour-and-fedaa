import 'dart:convert';

import '../../data/content/lesson.dart' show Recitation;

/// عنصر في لعبة: صورة (رمز) + كلمة + ما يُقال، وصفات اختيارية تستعملها بعض الألعاب.
class GameItem {
  const GameItem({
    required this.id,
    required this.emoji,
    required this.label,
    this.say,
    this.recite,
    this.group,
    this.letter,
    this.extra = const {},
  });

  final String id;
  final String emoji;
  final String label;

  /// ما يُنطق (الافتراضي: الكلمة). لا يكون نص آية أو حديث أبدًا.
  final String? say;

  /// تلاوة مسجّلة (لألعاب القرآن): يقرأها الشيخ بدل أي نطق آلي.
  final Recitation? recite;

  /// مجموعة العنصر في ألعاب الفرز (لون، شكل، نوع…).
  final String? group;

  /// الحرف الأول (لألعاب الحروف).
  final String? letter;
  final Map<String, String> extra;

  String get spoken => say ?? label;

  /// قيمة حقل بالاسم (للعرض المرن في الألعاب).
  String field(String name) => switch (name) {
        'emoji' => emoji,
        'label' => label,
        'say' => spoken,
        'letter' => letter ?? '',
        'group' => group ?? '',
        _ => extra[name] ?? '',
      };

  factory GameItem.fromJson(Map<String, dynamic> j) => GameItem(
        id: j['id'] as String,
        emoji: j['emoji'] as String? ?? '',
        label: j['label'] as String? ?? '',
        say: j['say'] as String?,
        recite: Recitation.fromJson(j['recite']),
        group: j['group'] as String?,
        letter: j['letter'] as String?,
        extra: {
          for (final e in (j['extra'] as Map<String, dynamic>? ?? const {}).entries) e.key: '${e.value}',
        },
      );
}

/// مجموعة (سلة) في ألعاب الفرز.
class GameGroup {
  const GameGroup({required this.id, required this.emoji, required this.label, this.color});

  final String id;
  final String emoji;
  final String label;
  final int? color;

  factory GameGroup.fromJson(Map<String, dynamic> j) => GameGroup(
        id: j['id'] as String,
        emoji: j['emoji'] as String? ?? '',
        label: j['label'] as String? ?? '',
        color: j['color'] == null ? null : int.parse((j['color'] as String).replaceFirst('#', 'FF'), radix: 16),
      );
}

/// جولة مكتوبة يدويًا (ألعاب المواقف): سؤال منطوق + اختيارات + الصحيح.
class GameScenario {
  const GameScenario({required this.emoji, required this.say, required this.options, required this.answer, this.text});

  final String emoji;
  final String say;
  final String? text;
  final List<GameItem> options;
  final int answer;

  factory GameScenario.fromJson(Map<String, dynamic> j) {
    final opts = [
      for (final (i, o) in (j['options'] as List).cast<Map<String, dynamic>>().indexed)
        GameItem.fromJson({'id': '$i', ...o}),
    ];
    final a = j['answer'] as int;
    if (a < 0 || a >= opts.length) throw FormatException('answer out of range: ${j['say']}');
    return GameScenario(emoji: j['emoji'] as String? ?? '', say: j['say'] as String, text: j['text'] as String?, options: opts, answer: a);
  }
}

/// مستوى: إعدادات الصعوبة لعمر معيّن (عدد الجولات والاختيارات والعناصر…).
class GameLevel {
  const GameLevel({required this.key, required this.title, required this.rounds, this.sub, this.params = const {}});

  final String key;
  final String title;
  final String? sub;
  final int rounds;
  final Map<String, dynamic> params;

  int intParam(String k, int fallback) => (params[k] as num?)?.toInt() ?? fallback;
  String strParam(String k, String fallback) => params[k] as String? ?? fallback;
  bool boolParam(String k, {bool fallback = false}) => params[k] as bool? ?? fallback;
  List<String> listParam(String k) => [for (final v in (params[k] as List? ?? const [])) '$v'];

  /// عدد النجوم المطلوب لفتح المستوى التالي (60% من الجولات، بلا إحباط).
  int get passStars => (rounds * 0.6).ceil();

  factory GameLevel.fromJson(Map<String, dynamic> j) {
    final params = Map<String, dynamic>.of(j)..removeWhere((k, _) => const {'key', 'title', 'sub', 'rounds'}.contains(k));
    return GameLevel(
      key: j['key'] as String,
      title: j['title'] as String,
      sub: j['sub'] as String?,
      rounds: (j['rounds'] as num?)?.toInt() ?? 5,
      params: params,
    );
  }
}

/// نسخة اللعبة لعمر معيّن: ليست نسخًا للعبة نفسها، بل طريقة لعب وصعوبة مختلفة.
class GameTrack {
  const GameTrack({required this.levels, this.mode = 'default', this.prompt, this.params = const {}});

  final List<GameLevel> levels;

  /// طريقة اللعب لهذا العمر (مثلًا: tap للصغيرة و drag للكبيرة).
  final String mode;
  final String? prompt;
  final Map<String, dynamic> params;

  factory GameTrack.fromJson(Map<String, dynamic> j) => GameTrack(
        levels: [for (final l in (j['levels'] as List).cast<Map<String, dynamic>>()) GameLevel.fromJson(l)],
        mode: j['mode'] as String? ?? 'default',
        prompt: j['prompt'] as String?,
        params: Map<String, dynamic>.of(j)..removeWhere((k, _) => const {'levels', 'mode', 'prompt'}.contains(k)),
      );
}

/// أنواع الألعاب (كل نوع له محرك واحد يقرأ محتواه من البيانات).
class GameTypes {
  static const choose = 'choose';
  static const order = 'order';
  static const memory = 'memory';
  static const sort = 'sort';
  static const count = 'count';
  static const find = 'find';
  static const scenario = 'scenario';
  static const all = {choose, order, memory, sort, count, find, scenario};
}

class GameDef {
  const GameDef({
    required this.id,
    required this.section,
    required this.title,
    required this.emoji,
    required this.type,
    required this.items,
    required this.fedaa,
    required this.nour,
    this.intro,
    this.goal,
    this.groups = const [],
    this.scenarios = const [],
    this.respectful = false,
    this.minAge = 3,
  });

  final String id;
  final String section;
  final String title;
  final String emoji;
  final String type;

  /// جملة تُقال عند فتح اللعبة.
  final String? intro;

  /// الهدف التعليمي (يظهر للأهل).
  final String? goal;
  final List<GameItem> items;
  final List<GameGroup> groups;
  final List<GameScenario> scenarios;
  final GameTrack fedaa;
  final GameTrack nour;

  /// قرآن/أذكار/صلاة: لا مؤثرات فوق التلاوة ولا احتفال صاخب.
  final bool respectful;

  /// أصغر عمر تناسبه اللعبة (بعض الألعاب لفداء فقط).
  final int minAge;

  bool fitsAge(int age) => age >= minAge;

  GameTrack trackFor(int age) => age <= 4 ? nour : fedaa;

  GameItem item(String id) => items.firstWhere((i) => i.id == id);

  factory GameDef.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String;
    if (!GameTypes.all.contains(type)) throw FormatException('unknown game type $type');
    return GameDef(
      id: j['id'] as String,
      section: j['section'] as String,
      title: j['title'] as String,
      emoji: j['emoji'] as String,
      type: type,
      intro: j['intro'] as String?,
      goal: j['goal'] as String?,
      respectful: j['respectful'] as bool? ?? false,
      minAge: (j['minAge'] as num?)?.toInt() ?? 3,
      items: [for (final i in (j['items'] as List? ?? const []).cast<Map<String, dynamic>>()) GameItem.fromJson(i)],
      groups: [for (final g in (j['groups'] as List? ?? const []).cast<Map<String, dynamic>>()) GameGroup.fromJson(g)],
      scenarios: [for (final s in (j['scenarios'] as List? ?? const []).cast<Map<String, dynamic>>()) GameScenario.fromJson(s)],
      fedaa: GameTrack.fromJson(j['fedaa'] as Map<String, dynamic>),
      nour: GameTrack.fromJson((j['nour'] ?? j['fedaa']) as Map<String, dynamic>),
    );
  }
}

/// كتالوج الألعاب: من ملف assets/content/games.json (ولاحقًا حزم تُنزَّل مرة وتُحفظ).
class GameCatalog {
  const GameCatalog(this.games);

  final List<GameDef> games;

  static const asset = 'assets/content/games.json';

  static GameCatalog parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final games = [for (final g in (doc['games'] as List).cast<Map<String, dynamic>>()) GameDef.fromJson(g)];
    final ids = <String>{};
    for (final g in games) {
      if (!ids.add(g.id)) throw FormatException('duplicate game id ${g.id}');
    }
    return GameCatalog(games);
  }

  /// يدمج حزمة إضافية (لعبة جديدة تحل محل القديمة بنفس المعرّف).
  GameCatalog merge(GameCatalog other) {
    final byId = {for (final g in games) g.id: g};
    for (final g in other.games) {
      byId[g.id] = g;
    }
    return GameCatalog(byId.values.toList());
  }

  GameDef? byId(String id) {
    for (final g in games) {
      if (g.id == id) return g;
    }
    return null;
  }
}
