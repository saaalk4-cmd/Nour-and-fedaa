import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pop_tap.dart';
import 'emoji_art.dart';

/// بطاقة قسم ملوّنة: تدرّج لوني، أيقونة كبيرة داخل دائرة مضيئة، دوائر زخرفية، وظل ناعم.
class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.color,
    required this.onTap,
    this.emojiSize = 46,
    this.badge,
  });

  final String emoji;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final double emojiSize;

  /// علامة صغيرة في الزاوية (مثل ⭐ أو ✅).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor();
    return PopTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [light, dark],
          ),
          boxShadow: [
            BoxShadow(color: dark.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned(
                top: -26,
                left: -22,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                bottom: -34,
                right: -18,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) => Center(
                    // يصغّر المحتوى تلقائيًا ليتسع في الشاشات الصغيرة أو الخط الكبير.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: box.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                shape: BoxShape.circle,
                              ),
                              child: EmojiPic(emoji, size: emojiSize),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.display(21, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(top: 10, left: 12, child: Text(badge!, style: const TextStyle(fontSize: 26))),
            ],
          ),
        ),
      ),
    );
  }
}
