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

/// أسماء ملفات الصور في assets/art/ (مقصوصة من ورقة العناصر المعتمدة).
class Art {
  static const String fedaa = 'char_fedaa';
  static const String nour = 'char_nour';
  static const String lamaa = 'lamaa';
  static const String star = 'star_on';
  static const String starOff = 'star_off';
  static const String gift = 'gift';
  static const String chest = 'chest';
  static const String lock = 'ic_lock';
  static const String home = 'ic_home';
  static const String back = 'ic_back';
  static const String sound = 'ic_sound';
  static const String check = 'ic_check';
  static const String question = 'ic_question';
  static const String signpost = 'signpost';
  static const String flower = 'flower';
  static const String foliage = 'foliage';
  static const String sceneCastle = 'scene_castle';
  static const String sceneHouse = 'scene_house';
  static const String sceneMountain = 'scene_mountain';

  /// كل الأسماء (للاختبار).
  static const List<String> all = [
    fedaa, nour, lamaa, star, starOff, gift, chest, lock, home, back, sound, check,
    question, signpost, flower, foliage, sceneCastle, sceneHouse, sceneMountain,
    'ic_star', 'ic_trophy', 'ic_gift', 'ic_gear', 'ic_music', 'ic_crown', 'ic_info',
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
