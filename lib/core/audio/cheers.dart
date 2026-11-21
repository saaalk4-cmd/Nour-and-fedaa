/// عبارات التشجيع (تتنوع في كل مرة ولا تتكرر بالتتابع). {n} = اسم الطفلة.
/// هذا الملف كله يُسجَّل بصوت عالي الجودة في CI (tools/build_voice.py)، ويمكن للأهل تسجيله بصوتهم.
class Cheers {
  static const praise = <String>[
    'أحسنتِ يا {n}!',
    'ما شاء الله عليكِ يا {n}!',
    'رائعة يا {n}!',
    'يا سلام يا {n}!',
    'ممتاز!',
    'نجمة اليوم',
  ];

  /// ثلاث إجابات صحيحة متتالية من أول مرة.
  static const streak = <String>[
    'ما شاء الله! ثلاث إجابات صحيحة ورا بعض يا {n}',
    'ما شاء الله عليكِ! أنتِ بطلة يا {n}',
  ];

  static const tryAgain = <String>[
    'قريبة جدًا! جربي مرة ثانية',
    'حاولي مرة أخرى',
    'ممتاز، جربي مرة ثانية',
  ];

  static const finishLevel = <String>[
    'ما شاء الله يا {n}! أكملتِ المستوى',
  ];

  static int _i = 0;

  static String _pick(List<String> xs, String name) => xs[_i++ % xs.length].replaceAll('{n}', name);

  static String forPraise(String name) => _pick(praise, name);
  static String forStreak(String name) => _pick(streak, name);
  static String forTryAgain(String name) => _pick(tryAgain, name);
}
