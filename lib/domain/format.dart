/// تنسيق مدة الاستخدام بالعربية للوالدين.
String formatUsage(int seconds) {
  if (seconds < 60) return 'أقل من دقيقة';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes دقيقة';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours ساعة' : '$hours ساعة و$rest دقيقة';
}

/// وصف آخر نشاط (اليوم / أمس / قبل N أيام) بحسب التاريخ وليس الساعات.
String describeLastActivity(DateTime? last, DateTime now) {
  if (last == null) return 'لا يوجد نشاط بعد';
  final a = DateTime.utc(last.year, last.month, last.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days == 2) return 'قبل يومين';
  if (days <= 10) return 'قبل $days أيام';
  return 'قبل $days يومًا';
}
