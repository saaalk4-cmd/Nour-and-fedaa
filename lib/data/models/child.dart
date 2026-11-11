class Child {
  const Child({
    required this.id,
    required this.name,
    required this.age,
    this.stars = 0,
    this.points = 0,
  });

  final int id;
  final String name;
  final int age;
  final int stars;
  final int points;

  /// المستوى يرتفع كل 10 نجوم.
  int get level => stars ~/ 10 + 1;

  /// مرحلة عمرية: تحدد شكل المحتوى المعروض (3-4 سنوات أبسط من 5-6).
  AgeGroup get ageGroup => age <= 4 ? AgeGroup.early : AgeGroup.preschool;

  factory Child.fromMap(Map<String, Object?> m) => Child(
        id: m['id']! as int,
        name: m['name']! as String,
        age: m['age']! as int,
        stars: (m['stars'] as int?) ?? 0,
        points: (m['points'] as int?) ?? 0,
      );
}

enum AgeGroup { early, preschool }
