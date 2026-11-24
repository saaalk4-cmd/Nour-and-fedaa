import 'arabic_digits.dart';

/// الفئات العمرية الأربع في براق. تحدد شكل الواجهة والمحتوى.
enum AgeBand {
  buraem('البراعم', 2, 4),
  atfal('الأطفال', 5, 7),
  nashia('الناشئة', 8, 11),
  murahiqun('المراهقون', 12, 14);

  const AgeBand(this.label, this.minAge, this.maxAge);

  final String label;
  final int minAge;
  final int maxAge;

  /// مثال: «٢ إلى ٤ سنوات».
  String get rangeLabel =>
      '${toArabicDigits(minAge)} إلى ${toArabicDigits(maxAge)} سنوات';

  static AgeBand? byName(String? name) {
    for (final b in AgeBand.values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// أصغر وأكبر عمر يخدمه التطبيق.
const int kMinSupportedAge = 2;
const int kMaxSupportedAge = 14;

bool isSupportedAge(int ageYears) =>
    ageYears >= kMinSupportedAge && ageYears <= kMaxSupportedAge;

/// العمر بالسنوات الكاملة من شهر وسنة الميلاد.
int ageInYears(int birthYear, int birthMonth, {DateTime? now}) {
  final n = now ?? DateTime.now();
  var age = n.year - birthYear;
  if (n.month < birthMonth) age -= 1;
  return age < 0 ? 0 : age;
}

/// الفئة المقترحة لعمر معيّن (يُقصّ خارج المدى إلى أقرب فئة).
AgeBand bandForAge(int ageYears) {
  if (ageYears <= 4) return AgeBand.buraem;
  if (ageYears <= 7) return AgeBand.atfal;
  if (ageYears <= 11) return AgeBand.nashia;
  return AgeBand.murahiqun;
}
