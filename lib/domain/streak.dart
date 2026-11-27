/// أيام متتالية فيها درس مكتمل، تنتهي اليوم أو أمس
/// (لو لم يُكمل درسًا اليوم بعدُ، لا تنقطع السلسلة حتى نهاية اليوم).
int streakDays(Iterable<DateTime> completions, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final days = completions.map(day).toSet();
  var cursor = day(now);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(cursor)) {
    n++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return n;
}

/// عدد الدروس المكتملة في يوم معيّن.
int lessonsOn(Iterable<DateTime> completions, DateTime dayOf) => completions
    .where((d) =>
        d.year == dayOf.year && d.month == dayOf.month && d.day == dayOf.day)
    .length;
