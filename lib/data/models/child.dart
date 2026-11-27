import '../../domain/age_band.dart';

/// أفاتارات تجريدية (بلا وجوه أو تجسيد).
class Avatars {
  static const all = <String, String>{
    'star': '⭐',
    'crescent': '🌙',
    'leaf': '🍃',
    'cloud': '☁️',
    'sun': '☀️',
    'flower': '🌸',
  };

  static String emoji(String id) => all[id] ?? all['star']!;
}

class Child {
  const Child({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.birthYear,
    required this.birthMonth,
    this.bandOverride,
    this.stars = 0,
    this.points = 0,
    this.cloudId,
  });

  final int id;

  /// لقب وليس الاسم الحقيقي.
  final String nickname;
  final String avatar;
  final int birthYear;
  final int birthMonth;

  /// إن غيّر ولي الأمر المسار عن المقترح من العمر.
  final AgeBand? bandOverride;
  final int stars;
  final int points;

  /// معرّف النسخة السحابية (للمزامنة).
  final String? cloudId;

  int ageYears({DateTime? now}) => ageInYears(birthYear, birthMonth, now: now);

  /// المسار المعروض: المختار يدويًا، وإلا المقترح من العمر.
  AgeBand band({DateTime? now}) =>
      bandOverride ?? bandForAge(ageYears(now: now));

  /// المستوى يرتفع كل 10 نجوم.
  int get level => stars ~/ 10 + 1;

  String get avatarEmoji => Avatars.emoji(avatar);

  factory Child.fromMap(Map<String, Object?> m) => Child(
        id: m['id']! as int,
        nickname: m['nickname']! as String,
        avatar: (m['avatar'] as String?) ?? 'star',
        birthYear: m['birth_year']! as int,
        birthMonth: m['birth_month']! as int,
        bandOverride: AgeBand.byName(m['band_override'] as String?),
        stars: (m['stars'] as int?) ?? 0,
        points: (m['points'] as int?) ?? 0,
        cloudId: m['cloud_id'] as String?,
      );
}

/// بيانات طفل قيد الإضافة (قبل الحفظ).
class ChildDraft {
  const ChildDraft({
    this.nickname = '',
    this.avatar = 'star',
    this.birthYear,
    this.birthMonth,
  });

  final String nickname;
  final String avatar;
  final int? birthYear;
  final int? birthMonth;

  ChildDraft copyWith({
    String? nickname,
    String? avatar,
    int? birthYear,
    int? birthMonth,
  }) =>
      ChildDraft(
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        birthYear: birthYear ?? this.birthYear,
        birthMonth: birthMonth ?? this.birthMonth,
      );

  bool get isComplete =>
      nickname.trim().isNotEmpty && birthYear != null && birthMonth != null;

  int? ageYears({DateTime? now}) => (birthYear == null || birthMonth == null)
      ? null
      : ageInYears(birthYear!, birthMonth!, now: now);
}
