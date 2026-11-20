import 'dart:convert';

import '../../data/content/quran.dart';
import '../../data/repositories/settings_repository.dart';

/// حالة سورة في الحفظ.
enum HifzStatus {
  /// محفوظة: تدخل المراجعة بالدور.
  memorized,

  /// بدأت حفظها (الحفظ الجديد واقف فيها).
  learning,

  /// لم تبدأ بعد.
  fresh,
}

/// مقطع آيات من سورة.
class AyahRange {
  const AyahRange(this.surah, this.from, this.to);

  final int surah;
  final int from;
  final int to;

  int get length => to - from + 1;

  @override
  bool operator ==(Object other) => other is AyahRange && other.surah == surah && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(surah, from, to);

  @override
  String toString() => '$surah:$from-$to';
}

/// ورد اليوم: حفظ جديد (مقطع) ومراجعة (سور محفوظة كاملة).
class DailyWird {
  const DailyWird({required this.newPart, required this.review, required this.newDone, required this.reviewDone});

  /// null لو أنهت كل الجديد.
  final AyahRange? newPart;
  final List<int> review;
  final bool newDone;
  final bool reviewDone;

  bool get allDone => (newPart == null || newDone) && (review.isEmpty || reviewDone);
}

/// تقدم الحفظ لطفلة واحدة (يُحفظ في الإعدادات نصًا).
///
/// فداء: محفوظ من الطلاق (65) إلى الناس، والجديد من المجادلة (58) بالترتيب، 3 آيات يوميًا، ومراجعة يومية بالدور.
/// نور: تسمع جزء عمّ وتبارك فقط (بلا حفظ مطلوب)، فـ [newOrder] فارغ.
class HifzProgress {
  HifzProgress({
    required this.memorized,
    required this.newOrder,
    required this.nextSurahIdx,
    required this.nextAyah,
    required this.reviewIdx,
    required this.listened,
    required this.days,
    this.perDay = 3,
  });

  final Set<int> memorized;

  /// ترتيب السور الجديدة للحفظ.
  final List<int> newOrder;
  int nextSurahIdx;
  int nextAyah;
  int reviewIdx;

  /// سور استمعت لها نور كاملة (نجمة).
  final Set<int> listened;

  /// ما أُنجز في كل يوم: day → {'new': '58:1-3', 'review': true}
  final Map<String, Map<String, dynamic>> days;
  final int perDay;

  /// البداية الافتراضية حسب البنت (بطلب الأم).
  factory HifzProgress.initialFor({required String name, required int age}) {
    final older = name.contains('فداء') || age >= 5;
    return HifzProgress(
      memorized: older ? {for (var s = 65; s <= 114; s++) s} : <int>{},
      newOrder: older ? const [58, 59, 60, 61, 62, 63, 64] : const [],
      nextSurahIdx: 0,
      nextAyah: 1,
      reviewIdx: 0,
      listened: <int>{},
      days: {},
    );
  }

  int? get currentSurah => nextSurahIdx < newOrder.length ? newOrder[nextSurahIdx] : null;

  HifzStatus statusOf(int surah) {
    if (memorized.contains(surah)) return HifzStatus.memorized;
    if (surah == currentSurah && nextAyah > 1) return HifzStatus.learning;
    return HifzStatus.fresh;
  }

  /// المقطع الجديد التالي (3 آيات، أو ما بقي من السورة).
  AyahRange? nextNew(QuranContent q) {
    final s = currentSurah;
    if (s == null) return null;
    final count = q.surahs.firstWhere((x) => x.surahNumber == s).ayahs.length;
    final to = (nextAyah + perDay - 1).clamp(nextAyah, count);
    return AyahRange(s, nextAyah, to);
  }

  /// سور المراجعة: بالدور من الأقصر للأطول (من الناس إلى الطلاق)، بحد ~20 آية أو 3 سور.
  List<int> nextReview(QuranContent q, {int budget = 20, int maxSurahs = 3}) {
    final list = memorized.toList()..sort((a, b) => b.compareTo(a));
    if (list.isEmpty) return const [];
    final out = <int>[];
    var ayat = 0;
    var i = reviewIdx % list.length;
    while (out.length < maxSurahs && out.length < list.length) {
      final s = list[i];
      final n = q.surahs.firstWhere((x) => x.surahNumber == s, orElse: () => q.surahs.first).ayahs.length;
      if (out.isNotEmpty && ayat + n > budget) break;
      out.add(s);
      ayat += n;
      i = (i + 1) % list.length;
    }
    return out;
  }

  DailyWird wirdFor(String day, QuranContent q) {
    final d = days[day] ?? const {};
    final done = d['new'] as String?;
    AyahRange? part;
    if (done != null) {
      final m = RegExp(r'^(\d+):(\d+)-(\d+)$').firstMatch(done);
      part = m == null ? null : AyahRange(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    } else {
      part = nextNew(q);
    }
    final review = (d['reviewList'] as List<dynamic>?)?.cast<int>() ?? nextReview(q);
    return DailyWird(newPart: part, review: review, newDone: done != null, reviewDone: d['review'] == true);
  }

  /// أنهت المقطع الجديد اليوم (حفظته): يتقدم الموضع؛ وإن انتهت السورة تصير محفوظة.
  void completeNew(String day, QuranContent q) {
    final part = nextNew(q);
    if (part == null || days[day]?['new'] != null) return;
    (days[day] ??= {})['new'] = part.toString();
    final count = q.surahs.firstWhere((x) => x.surahNumber == part.surah).ayahs.length;
    if (part.to >= count) {
      memorized.add(part.surah);
      nextSurahIdx++;
      nextAyah = 1;
    } else {
      nextAyah = part.to + 1;
    }
  }

  /// أنهت مراجعة اليوم: يتقدم الدور.
  void completeReview(String day, QuranContent q) {
    final d = days[day] ??= {};
    if (d['review'] == true) return;
    final list = (d['reviewList'] as List<dynamic>?)?.cast<int>() ?? nextReview(q);
    d['review'] = true;
    d['reviewList'] = list;
    reviewIdx += list.length;
  }

  /// تعديل الأهل: هذه السورة محفوظة أو لا.
  void setMemorized(int surah, bool yes) => yes ? memorized.add(surah) : memorized.remove(surah);

  String encode() => jsonEncode({
        'v': 1,
        'memorized': memorized.toList()..sort(),
        'newOrder': newOrder,
        'nextSurahIdx': nextSurahIdx,
        'nextAyah': nextAyah,
        'reviewIdx': reviewIdx,
        'listened': listened.toList()..sort(),
        'days': days,
      });

  factory HifzProgress.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return HifzProgress(
      memorized: {for (final s in (j['memorized'] as List<dynamic>? ?? const [])) (s as num).toInt()},
      newOrder: [for (final s in (j['newOrder'] as List<dynamic>? ?? const [])) (s as num).toInt()],
      nextSurahIdx: (j['nextSurahIdx'] as num?)?.toInt() ?? 0,
      nextAyah: (j['nextAyah'] as num?)?.toInt() ?? 1,
      reviewIdx: (j['reviewIdx'] as num?)?.toInt() ?? 0,
      listened: {for (final s in (j['listened'] as List<dynamic>? ?? const [])) (s as num).toInt()},
      days: {
        for (final e in ((j['days'] as Map<String, dynamic>?) ?? const {}).entries)
          e.key: Map<String, dynamic>.from(e.value as Map),
      },
    );
  }
}

/// حفظ التقدم لكل بنت في الإعدادات.
class HifzRepository {
  HifzRepository(this._settings);

  final SettingsRepository _settings;

  Future<HifzProgress> load({required int childId, required String name, required int age}) async {
    final raw = await _settings.getValue('hifz_$childId');
    if (raw == null || raw.isEmpty) return HifzProgress.initialFor(name: name, age: age);
    try {
      return HifzProgress.decode(raw);
    } catch (_) {
      return HifzProgress.initialFor(name: name, age: age);
    }
  }

  Future<void> save(int childId, HifzProgress p) => _settings.setValue('hifz_$childId', p.encode());
}

/// جزء السورة (28–30) أو null.
int? juzOfSurah(int s) => s >= 58 && s <= 66 ? 28 : (s >= 67 && s <= 77 ? 29 : (s >= 78 && s <= 114 ? 30 : null));
