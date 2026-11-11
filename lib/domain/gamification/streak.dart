/// مفتاح اليوم بصيغة yyyy-MM-dd (بالتوقيت المحلي).
String dayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class StreakUpdate {
  const StreakUpdate({
    required this.current,
    required this.best,
    required this.extended,
    required this.welcomeBack,
  });

  final int current;
  final int best;

  /// true إذا زادت السلسلة اليوم.
  final bool extended;

  /// true إذا غابت الطفلة أيامًا: نرحّب بها ولا نقول إنها «خسرت».
  final bool welcomeBack;
}

class StreakCalculator {
  const StreakCalculator._();

  static DateTime _utcDay(String key) {
    final parts = key.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// السلسلة التي تُعرض على الشاشة: تبقى إذا كان آخر نشاط اليوم أو أمس،
  /// وإلا نعرض 0 (دعوة لبداية جديدة) بدون أي رسالة خسارة.
  static int activeStreak({
    required String? lastDay,
    required String today,
    required int current,
  }) {
    if (lastDay == null) return 0;
    final gap = _utcDay(today).difference(_utcDay(lastDay)).inDays;
    return gap <= 1 ? current : 0;
  }

  static StreakUpdate update({
    required String? lastDay,
    required String today,
    required int current,
    required int best,
  }) {
    int maxOf(int a, int b) => a > b ? a : b;

    if (lastDay == null) {
      return StreakUpdate(
        current: 1,
        best: maxOf(best, 1),
        extended: true,
        welcomeBack: false,
      );
    }
    // نستخدم UTC حتى لا يتأثر الحساب بتغيير التوقيت الصيفي.
    final gap = _utcDay(today).difference(_utcDay(lastDay)).inDays;
    if (gap <= 0) {
      final keep = maxOf(current, 1);
      return StreakUpdate(
        current: keep,
        best: maxOf(best, keep),
        extended: false,
        welcomeBack: false,
      );
    }
    if (gap == 1) {
      final next = current + 1;
      return StreakUpdate(
        current: next,
        best: maxOf(best, next),
        extended: true,
        welcomeBack: false,
      );
    }
    return StreakUpdate(
      current: 1,
      best: maxOf(best, 1),
      extended: true,
      welcomeBack: true,
    );
  }
}
