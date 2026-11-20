import 'dart:math';

/// كود الأسرة: يربط تليفون البنات بتليفون الأهل، وهو اسم مستند الأسرة على الخدمة.
/// 16 حرفًا من 32 رمزًا (بلا 0 O 1 I L لتجنّب اللبس) ≈ 80 بت: لا يُخمَّن.
class FamilyCode {
  const FamilyCode._();

  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 16;

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(length, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  /// يقبل ما تكتبه الأم بأي شكل (مسافات، شرطات، حروف صغيرة) ويرجع الكود أو null.
  static String? normalize(String input) {
    final c = input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (c.length != length) return null;
    for (final ch in c.split('')) {
      if (!alphabet.contains(ch)) return null;
    }
    return c;
  }

  /// للعرض: ABCD-EFGH-JKMN-PQRS
  static String pretty(String code) => [
        for (var i = 0; i < code.length; i += 4) code.substring(i, min(i + 4, code.length)),
      ].join('-');
}
