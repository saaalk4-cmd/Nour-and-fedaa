/// إعدادات الوقت التي يضبطها ولي الأمر.
class TimeSettings {
  const TimeSettings({this.dailyLimitMin = 0, this.quietFromMin = -1, this.quietToMin = -1, this.breakEveryMin = 15});

  /// الحد اليومي بالدقائق لكل طفلة (0 = بلا حد).
  final int dailyLimitMin;

  /// ساعات عدم الاستخدام: من/إلى بالدقائق من منتصف الليل (-1 = بلا قيد). تدعم العبور بعد منتصف الليل.
  final int quietFromMin;
  final int quietToMin;

  /// اقتراح استراحة بعد كم دقيقة لعب متواصل.
  final int breakEveryMin;

  bool get hasQuietHours => quietFromMin >= 0 && quietToMin >= 0 && quietFromMin != quietToMin;

  TimeSettings copyWith({int? dailyLimitMin, int? quietFromMin, int? quietToMin, int? breakEveryMin}) => TimeSettings(
        dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin,
        quietFromMin: quietFromMin ?? this.quietFromMin,
        quietToMin: quietToMin ?? this.quietToMin,
        breakEveryMin: breakEveryMin ?? this.breakEveryMin,
      );
}

enum RestReason {
  /// انتهى وقت اللعب اليومي.
  limit,

  /// الآن خارج الأوقات المسموحة.
  hours,
}

/// هل حان وقت الراحة؟ (null = يمكنها اللعب). لا يمنع شيئًا فجأة وسط شاشة بلا كلام:
/// الشاشة التي تُعرض لطيفة بصوت لَمعة، وولي الأمر يستطيع السماح.
RestReason? checkRest({
  required TimeSettings settings,
  required int usedSeconds,
  required DateTime now,
  int extraMin = 0,
  bool overriddenToday = false,
}) {
  if (overriddenToday) return null;
  if (settings.hasQuietHours) {
    final m = now.hour * 60 + now.minute;
    final from = settings.quietFromMin, to = settings.quietToMin;
    final quiet = from < to ? (m >= from && m < to) : (m >= from || m < to);
    if (quiet) return RestReason.hours;
  }
  if (settings.dailyLimitMin > 0 && usedSeconds >= (settings.dailyLimitMin + extraMin) * 60) {
    return RestReason.limit;
  }
  return null;
}
