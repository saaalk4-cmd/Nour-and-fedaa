/// جدول المراجعة المتباعدة (صناديق ليتنر): بعد كل مراجعة ناجحة تتباعد المرة التالية.
const reviewIntervalsDays = [1, 3, 7, 14, 30];

int get maxReviewBox => reviewIntervalsDays.length - 1;

/// الصندوق بعد مراجعة: النجاح يرفعه (حتى الأخير)، والنسيان يعيده إلى الأول.
int nextBox(int box, {required bool remembered}) =>
    remembered ? (box + 1 > maxReviewBox ? maxReviewBox : box + 1) : 0;

/// تاريخ الاستحقاق التالي لصندوق معيّن، بدءًا من [today] (يُهمل وقت اليوم).
DateTime dueDateFor(int box, DateTime today) {
  final base = DateTime(today.year, today.month, today.day);
  return base.add(Duration(days: reviewIntervalsDays[box]));
}
