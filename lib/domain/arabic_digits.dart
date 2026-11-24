const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// يحوّل الأرقام اللاتينية في أي قيمة إلى أرقام هندية-عربية (٠١٢٣…).
String toArabicDigits(Object value) {
  final s = value.toString();
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.write(_arabicIndic[unit - 0x30]);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
