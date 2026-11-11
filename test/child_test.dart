import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/models/child.dart';

void main() {
  test('age groups separate 3-year-old and 5-year-old content', () {
    const nour = Child(id: 1, name: 'نور', age: 3);
    const fedaa = Child(id: 2, name: 'فداء', age: 5);
    expect(nour.ageGroup, AgeGroup.early);
    expect(fedaa.ageGroup, AgeGroup.preschool);
  });

  test('level rises every 10 stars', () {
    const c = Child(id: 1, name: 'فداء', age: 5, stars: 25);
    expect(c.level, 3);
  });
}
