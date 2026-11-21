import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pop_tap.dart';

/// زر كبير بتدرّج لوني وخط العناوين، بحركة ضغطة؛ يصير رماديًا عند التعطيل.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.colors = const [Color(0xFF6BD36B), Color(0xFF2A9D8F)],
    this.height = 68,
  });

  final String label;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PopTap(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: enabled
              ? LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors)
              : const LinearGradient(colors: [Color(0xFFD5DCE3), Color(0xFFC3CCD5)]),
          boxShadow: enabled
              ? [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 8))]
              : const [],
        ),
        child: Text(label, style: AppText.display(26, color: Colors.white)),
      ),
    );
  }
}
