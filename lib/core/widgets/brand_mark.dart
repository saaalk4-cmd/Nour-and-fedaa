import 'package:flutter/material.dart';

/// علامة براق (الباء بالنقطة المعيّنة) بالذهبي.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.width = 120});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/mark_gold.png',
      width: width,
      semanticLabel: 'شعار براق',
      filterQuality: FilterQuality.medium,
    );
  }
}
