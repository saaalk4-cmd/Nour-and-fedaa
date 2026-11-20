import 'dart:math';

import '../../data/content/quran.dart';

/// آية واحدة في لعبة المراجعة.
class AyahRef {
  const AyahRef(this.surah, this.ayah, this.text);

  final int surah;
  final int ayah;
  final String text;

  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}

/// جولة «رتّبي الآيات»: آيات متتالية من سورة محفوظة، تُعرض مخلوطة.
class OrderRound {
  const OrderRound({required this.surahName, required this.correct, required this.shuffled});

  final String surahName;

  /// الترتيب الصحيح.
  final List<AyahRef> correct;
  final List<AyahRef> shuffled;
}

/// جولة «أكملي الآية»: تسمع آية، وتختار الآية التي بعدها.
class NextRound {
  const NextRound({required this.surahName, required this.heard, required this.options, required this.answer});

  final String surahName;
  final AyahRef heard;
  final List<AyahRef> options;
  final int answer;
}

/// يبني جولات المراجعة من محفوظ البنت فقط (لا جديد عليها هنا).
class HifzReview {
  HifzReview(this.q, Set<int> memorized, {Random? rng})
      : _rng = rng ?? Random(),
        _surahs = [for (final s in q.surahs) if (memorized.contains(s.surahNumber) && s.ayahs.length >= 3) s];

  final QuranContent q;
  final Random _rng;
  final List<Surah> _surahs;

  bool get canPlay => _surahs.isNotEmpty;

  /// أقصى طول للآيات المعروضة معًا، حتى تظهر كلها على شاشة الموبايل.
  static const int maxChars = 260;

  AyahRef _ref(Surah s, int i) => AyahRef(s.surahNumber, s.ayahs[i].number, s.ayahs[i].text);

  /// 3 أو 4 آيات متتالية قصيرة بما يكفي للشاشة. null لو لا يوجد محفوظ مناسب.
  OrderRound? order() {
    if (!canPlay) return null;
    for (var tries = 0; tries < 40; tries++) {
      final s = _surahs[_rng.nextInt(_surahs.length)];
      final want = min(s.ayahs.length, 3 + _rng.nextInt(2));
      final start = _rng.nextInt(s.ayahs.length - want + 1);
      final list = [for (var i = start; i < start + want; i++) _ref(s, i)];
      if (list.fold<int>(0, (n, a) => n + a.text.length) > maxChars && tries < 39) continue;
      final shuffled = [...list];
      // لازم المخلوط يختلف عن الصحيح.
      while (_same(shuffled, list)) {
        shuffled.shuffle(_rng);
      }
      return OrderRound(surahName: s.name, correct: list, shuffled: shuffled);
    }
    return null;
  }

  /// آية مسموعة، وثلاث اختيارات من نفس السورة، الصحيحة منها التي تليها.
  NextRound? next() {
    if (!canPlay) return null;
    final s = _surahs[_rng.nextInt(_surahs.length)];
    final i = _rng.nextInt(s.ayahs.length - 1);
    final heard = _ref(s, i);
    final right = _ref(s, i + 1);
    final others = [for (var k = 0; k < s.ayahs.length; k++) if (k != i && k != i + 1) _ref(s, k)]..shuffle(_rng);
    // سورة قصيرة (3 آيات): نكمل الاختيارات من سورة محفوظة أخرى.
    for (var tries = 0; others.length < 2 && tries < 20; tries++) {
      final o = _surahs[_rng.nextInt(_surahs.length)];
      if (o.surahNumber == s.surahNumber) continue;
      final a = _ref(o, _rng.nextInt(o.ayahs.length));
      if (!others.contains(a)) others.add(a);
    }
    final options = [right, ...others.take(2)]..shuffle(_rng);
    return NextRound(surahName: s.name, heard: heard, options: options, answer: options.indexOf(right));
  }

  static bool _same(List<AyahRef> a, List<AyahRef> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
