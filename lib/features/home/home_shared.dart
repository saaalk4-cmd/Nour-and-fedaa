import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// شريط التنقل السفلي لفئات الأطفال الأكبر.
class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key, this.dark = true});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    void soon() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قريبًا إن شاء الله')),
        );
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF16204A) : Colors.white,
        indicatorColor: AppColors.gold.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: dark ? AppColors.cream : AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: dark ? AppColors.cream : AppColors.navy),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 3) {
            context.push('/parent');
          } else if (i != 0) {
            soon();
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'دروسي'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined), label: 'إنجازاتي'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}

/// زر القفل الذي يفتح لوحة ولي الأمر.
class ParentLockButton extends StatelessWidget {
  const ParentLockButton({super.key, this.color = AppColors.navy});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'لوحة ولي الأمر',
      onPressed: () => context.push('/parent'),
      icon: Icon(Icons.lock_outline, color: color),
    );
  }
}

/// بلاطة قسم بحالتين: مفتوح أو مقفول «قريبًا».
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.color,
    required this.onTap,
    this.soon = false,
    this.textColor = AppColors.navy,
    this.emojiSize = 40,
    this.titleSize = 20,
  });

  final String emoji;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool soon;
  final Color textColor;
  final double emojiSize;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: soon ? 0.6 : 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: soon
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قريبًا إن شاء الله')),
                  )
              : onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(soon ? '🔒' : emoji,
                        style: TextStyle(fontSize: emojiSize)),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (soon)
                      Text('قريبًا إن شاء الله',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
