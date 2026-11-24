import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/child.dart';
import '../../domain/arabic_digits.dart';
import 'home_shared.dart';
import 'sections.dart';

/// رئيسية الأطفال (5–7): بطاقات ملوّنة وقصص، شريط تبويب، عدّاد نجوم.
class KidsHome extends StatelessWidget {
  const KidsHome({super.key, required this.child, required this.enabled});

  final Child child;
  final Map<String, bool> enabled;

  @override
  Widget build(BuildContext context) {
    final visible = appSections.where((s) => enabled[s.id] ?? true).toList();
    final open = visible.where((s) => !s.soon).toList();
    final soon = visible.where((s) => s.soon).toList();

    return Scaffold(
      backgroundColor: AppColors.navy,
      bottomNavigationBar: const HomeTabs(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            Row(
              children: [
                const BrandMark(width: 66),
                const SizedBox(width: 10),
                _StarChip(stars: child.stars),
                const Spacer(),
                const ParentLockButton(color: AppColors.cream),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'السلام عليكم يا ${child.nickname}',
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _ContinueCard(onTap: () => context.push('/section/quran')),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                for (final s in open)
                  SectionCard(
                    emoji: s.emoji,
                    title: s.title,
                    color: AppColors.cream,
                    titleSize: 18,
                    onTap: () => context.push('/section/${s.id}'),
                  ),
              ],
            ),
            if (soon.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final s in soon)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: SizedBox(
                          height: 110,
                          child: SectionCard(
                            emoji: s.emoji,
                            title: s.title,
                            color: AppColors.cream,
                            soon: true,
                            emojiSize: 28,
                            titleSize: 17,
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(toArabicDigits(stars),
                style: const TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 46)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ابدأ أول درس',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0,
                      minHeight: 10,
                      backgroundColor: Color(0xFFEBDDBE),
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_left, color: AppColors.navy, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
