import 'package:flutter/material.dart';

import 'art.dart';

/// «مكتبة الصور»: صورة مرسومة (Canva، أسلوب واحد) بدل الإيموجي أينما ظهر.
/// المفتاح إيموجي بلا محدّد الشكل (U+FE0F)؛ القيمة اسم ملف في assets/art.
/// أي إيموجي بلا صورة يبقى كما هو.
const Map<String, String> kEmojiArt = {
  // كروت الحروف
  '🐰': 'let_01', '🐇': 'let_01', '🦆': 'let_02', '🍎': 'let_03', '🦊': 'let_04', '🐫': 'let_05', '🐪': 'let_05',
  '🐴': 'let_06', '🐎': 'let_06', '🐑': 'let_07', '🐻': 'let_08', '🧸': 'let_08', '🌽': 'let_09', '🪶': 'let_10',
  '🦒': 'let_11', '🐟': 'let_12', '🐠': 'let_12', '☀': 'let_13', '🦅': 'let_14', '🐸': 'let_15', '✈': 'let_16',
  '✉': 'let_17', '🍇': 'let_18', '☁': 'let_19', '🐘': 'let_20', '🐱': 'let_21', '🐈': 'let_21', '🐶': 'let_22',
  '🐕': 'let_22', '🍋': 'let_23', '🍌': 'let_24', '🐝': 'let_25', '🎁': 'let_26', '🌹': 'let_27', '✋': 'let_28',
  '🖐': 'let_28', '👋': 'let_28',
  // أيقونات الأقسام
  '📖': 'sec_quran', '🕌': 'sec_prayer', '🌙': 'sec_adhkar', '❤': 'sec_akhlaq', '📜': 'sec_seerah',
  '🏅': 'sec_figures', '🌴': 'sec_prophets', '🏆': 'sec_achievements', '⭐': 'star_on', '🌟': 'star_on',
  // مكتبة الصور
  '🌳': 'pic_tree', '🍽': 'pic_plate', '💧': 'pic_water', '🐄': 'pic_cow', '🌸': 'pic_blossom', '🐦': 'pic_bird',
  '🤲': 'pic_dua', '🥛': 'pic_milk', '🧼': 'pic_soap', '🚗': 'pic_car', '🥕': 'pic_carrot', '🌷': 'pic_tulip',
  '🌱': 'pic_sprout', '👂': 'pic_ear', '🐔': 'pic_chicken', '🌧': 'pic_rain', '💎': 'pic_gem', '🏠': 'pic_house',
  '🦋': 'pic_butterfly', '👃': 'pic_nose', '⚽': 'pic_ball', '🎈': 'pic_balloon', '👩': 'pic_mom', '🗑': 'pic_trash',
  '🚪': 'pic_door', '🍓': 'pic_strawberry', '❄': 'pic_snow', '👵': 'pic_grandma', '🦁': 'pic_lion', '🛏': 'pic_bed',
  '🦶': 'pic_foot', '🧹': 'pic_broom', '🍞': 'pic_bread', '🍅': 'pic_tomato', '📚': 'pic_books', '🍬': 'pic_candy',
  '🌊': 'pic_wave', '🕒': 'pic_clock', '🌅': 'pic_sunrise', '🚢': 'pic_ship', '👨': 'pic_dad', '🔥': 'pic_fire',
  '👁': 'pic_eye', '🪑': 'pic_chair', '🍊': 'pic_orange', '🪥': 'pic_toothbrush', '🐭': 'pic_mouse', '🔑': 'pic_key',
  '🎧': 'pic_headphones',
  '🧩': 'pic_puzzle',
  '🃏': 'pic_cards',
  '🌈': 'pic_rainbow',
  '🔷': 'pic_shapes',
  '🌞': 'let_13',
  '💖': 'sec_akhlaq',
  '💛': 'sec_akhlaq',
  '🏡': 'pic_house',
  '🎨': 'pic_palette',
  '🔍': 'pic_magnifier',
  '🧠': 'pic_brain',
  '💡': 'pic_bulb',
  '😢': 'pic_sad',
  '😊': 'pic_smile',
  '🎮': 'pic_gamepad',
  '😴': 'pic_sleepy',
  '🐢': 'pic_turtle',
  '🍪': 'pic_cookie',
  '👧': 'pic_girl',
  '👦': 'pic_boy',
  '🥒': 'pic_cucumber',
  '🦌': 'pic_deer',
  '🌵': 'pic_cactus',
  '🎒': 'pic_backpack',
  '🧺': 'pic_basket',
  '🌿': 'pic_leaf',
  '🚒': 'pic_firetruck',
};

/// يزيل محدّد الشكل ليطابق المفاتيح.
String _norm(String s) => s.replaceAll('️', '').trim();

/// اسم الصورة لإيموجي واحد (أو null).
String? artForEmoji(String emoji) => kEmojiArt[_norm(emoji)];

/// إن كان النص تكرارًا لإيموجي واحد له صورة (مثل 🍎🍎🍎 في العدّ): (الصورة، العدد).
(String, int)? repeatedArt(String text) {
  final t = _norm(text);
  if (t.isEmpty) return null;
  for (final e in kEmojiArt.entries) {
    if (!t.startsWith(e.key)) continue;
    final n = t.length ~/ e.key.length;
    if (n >= 1 && n <= 12 && e.key * n == t) return (e.value, n);
  }
  return null;
}

/// يعرض الإيموجي صورةً مرسومة إن وُجدت (أو عدة صور للتكرار)، وإلا نصًا كما هو.
class EmojiPic extends StatelessWidget {
  const EmojiPic(this.text, {super.key, required this.size, this.style});

  final String text;

  /// حجم الإيموجي النصي؛ الصورة أكبر قليلًا لأن الإيموجي له هامش داخلي.
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final rep = repeatedArt(text);
    if (rep == null) return Text(text, style: (style ?? const TextStyle()).copyWith(fontSize: size, height: 1.1));
    final (art, n) = rep;
    if (n == 1) return ArtImage(art, width: size * 1.25, height: size * 1.25);
    final each = (size * 1.25 / (n <= 3 ? 1.6 : (n <= 6 ? 2.2 : 2.8))).clamp(18.0, size);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [for (var i = 0; i < n; i++) ArtImage(art, width: each, height: each)],
    );
  }
}
