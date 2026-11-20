import 'package:flutter/material.dart';

import 'pop_tap.dart';

/// قواعد التصميم المشتركة (صورة وصوت قبل الكلام).
class Kid {
  /// أصغر مساحة لمس مريحة لإصبع طفلة.
  static const double minTouch = 72;

  /// مدى الزوايا المستديرة: كبير وودود.
  static const double radiusL = 36;
  static const double radiusM = 24;

  static const Color sky = Color(0xFFBFE6FF);
  static const Color wood = Color(0xFFE8A957);
  static const Color woodDark = Color(0xFF9A5B22);
  static const Color pinkF = Color(0xFFFF8FB1); // فداء
  static const Color greenN = Color(0xFF7ED36B); // نور
}

/// أسماء ملفات الصور في assets/art/ (التصاميم المعتمدة، خلفيتها شفافة).
class Art {
  // الشخصيتان (وضعيات: ترحيب، تفكير، احتفال)
  static const String fedaaWelcome = 'fedaa_welcome';
  static const String fedaaThink = 'fedaa_think';
  static const String fedaaCheer = 'fedaa_cheer';
  static const String nourWelcome = 'nour_welcome';
  static const String nourThink = 'nour_think';
  static const String nourCheer = 'nour_cheer';

  // لَمعة (خمس وضعيات)
  static const String lamaaCalm = 'lamaa_calm';
  static const String lamaaPoint = 'lamaa_point';
  static const String lamaaCheer = 'lamaa_cheer';
  static const String lamaaThink = 'lamaa_think';
  static const String lamaaWelcome = 'lamaa_welcome';

  // أيقونات بلا كلمات
  static const String icGift = 'ic_gift';
  static const String icSound = 'ic_sound';
  static const String icBack = 'ic_back';
  static const String icHome = 'ic_home';
  static const String icLock = 'ic_lock';
  static const String starOn = 'star_on';
  static const String starOff = 'star_off';

  // مكافآت وبوابات
  static const String gate = 'gate';
  static const String medal = 'medal';

  // خلفيات
  static const String bgSky = 'bg_sky';
  static const String bgRiver = 'bg_river';
  static const String bgForest = 'bg_forest';
  static const String bgHouse = 'bg_house';
  static const String bgCastle = 'bg_castle';
  static const String bgPath = 'bg_path';

  // زينة المسار
  static const String decorTree1 = 'decor_tree1';
  static const String decorTree2 = 'decor_tree2';
  static const String decorTree3 = 'decor_tree3';
  static const String decorTree4 = 'decor_tree4';
  static const String decorBush = 'decor_bush';
  static const String decorFlowers1 = 'decor_flowers1';
  static const String decorFlowers2 = 'decor_flowers2';
  static const String decorRock = 'decor_rock';
  static const String decorSignpost = 'decor_signpost';

  // أسماء مختصرة مستعملة في الشاشات
  static const String fedaa = fedaaWelcome;
  static const String nour = nourWelcome;
  static const String lamaa = lamaaCalm;
  static const String star = starOn;
  static const String lock = icLock;
  static const String gift = icGift;
  static const String home = icHome;
  static const String back = icBack;
  static const String sound = icSound;
  static const String signpost = decorSignpost;

  /// خلفيات المسار تتبدل كل أسبوع.
  static const List<String> weekBackgrounds = [bgPath, bgForest, bgHouse, bgRiver, bgCastle, bgSky];

  /// زينة جانب المسار بالتناوب.
  static const List<String> decor = [
    decorTree1, decorFlowers1, decorTree3, decorRock, decorBush, decorTree4, decorFlowers2, decorTree2,
  ];

  // أيقونات الأقسام (Canva، أسلوب واحد).
  static const String secQuran = 'sec_quran';
  static const String secPrayer = 'sec_prayer';
  static const String secAdhkar = 'sec_adhkar';
  static const String secAkhlaq = 'sec_akhlaq';
  static const String secSeerah = 'sec_seerah';
  static const String secFigures = 'sec_figures';
  static const String secProphets = 'sec_prophets';
  static const String secLearn = 'sec_learn';
  static const String secAchievements = 'sec_achievements';

  /// كروت حروف نور (Canva): صورة أول كلمة لكل حرف بترتيب الحروف (let_01 = أرنب ... let_28 = يد).
  static const List<String> letters = ['let_01', 'let_02', 'let_03', 'let_04', 'let_05', 'let_06', 'let_07', 'let_08', 'let_09', 'let_10', 'let_11', 'let_12', 'let_13', 'let_14', 'let_15', 'let_16', 'let_17', 'let_18', 'let_19', 'let_20', 'let_21', 'let_22', 'let_23', 'let_24', 'let_25', 'let_26', 'let_27', 'let_28'];

  /// كل الملفات (للاختبار).
  static const List<String> all = [
    fedaaWelcome, fedaaThink, fedaaCheer, nourWelcome, nourThink, nourCheer,
    lamaaCalm, lamaaPoint, lamaaCheer, lamaaThink, lamaaWelcome,
    icGift, icSound, icBack, icHome, icLock, starOn, starOff,
    gate, medal,
    bgSky, bgRiver, bgForest, bgHouse, bgCastle, bgPath,
    decorTree1, decorTree2, decorTree3, decorTree4, decorBush, decorFlowers1, decorFlowers2,
    decorRock, decorSignpost,
    secQuran, secPrayer, secAdhkar, secAkhlaq, secSeerah, secFigures, secProphets, secLearn, secAchievements,
    ...letters,
  ];

  static String path(String name) => 'assets/art/$name.webp';
}

/// صورة من مجموعة العناصر. تفشل بهدوء (فراغ) لو الملف ناقص، فلا ينهار التطبيق.
class ArtImage extends StatelessWidget {
  const ArtImage(this.name, {super.key, this.width, this.height, this.fit = BoxFit.contain});

  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Art.path(name),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
    );
  }
}

/// زر بصورة فقط (بلا كلمة): مساحة لمس لا تقل عن [Kid.minTouch].
/// [label] للقارئ الصوتي (Semantics) لا يظهر على الشاشة.
class ArtButton extends StatelessWidget {
  const ArtButton({super.key, required this.art, required this.label, required this.onTap, this.size = 76});

  final String art;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size < Kid.minTouch ? Kid.minTouch : size;
    return Semantics(
      button: true,
      label: label,
      child: PopTap(
        onTap: onTap,
        child: SizedBox(width: s, height: s, child: Center(child: ArtImage(art, width: s * 0.95))),
      ),
    );
  }
}
