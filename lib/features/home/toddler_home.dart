import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/arabic_digits.dart';
import 'home_shared.dart';
import 'sections.dart';

/// رئيسية البراعم (2–4): بلاطات كبيرة بأيقونات وكلمات قليلة، بلا شريط تبويب.
class ToddlerHome extends StatelessWidget {
  const ToddlerHome({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const BrandMark(width: 70),
                  const Spacer(),
                  const ParentLockButton(),
                ],
              ),
              Text(child.avatarEmoji, style: const TextStyle(fontSize: 64)),
              Text(
                'أهلًا يا ${child.nickname}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // ثلاثة صفوف تتسع للمساحة المتاحة بلا قص أو تمرير.
                    const gap = 14.0;
                    final tileW = (box.maxWidth - gap) / 2;
                    final tileH = (box.maxHeight - 2 * gap) / 3;
                    return GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio: tileW / tileH,
                      children: [
                        for (final t in toddlerTiles)
                          SectionCard(
                            emoji: t.emoji,
                            title: t.title,
                            color: t.color,
                            soon: t.soon,
                            emojiSize: t.emoji.length > 2 ? 34 : 52,
                            titleSize: 22,
                            onTap: () => context.push('/section/${t.id}'),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              const _ReviewButton(),
              _Garden(stars: child.stars),
            ],
          ),
        ),
      ),
    );
  }
}

class _Garden extends StatelessWidget {
  const _Garden({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Text('حديقتي',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(i < stars ? '🌟' : '🌱',
                          style: const TextStyle(fontSize: 26)),
                    ),
                  const SizedBox(width: 8),
                  Text(toArabicDigits(stars),
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر «نراجع؟» يظهر فقط حين يوجد درس مستحق للمراجعة.
class _ReviewButton extends ConsumerWidget {
  const _ReviewButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueReviewProvider).valueOrNull ?? const [];
    if (due.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton(
          key: const Key('review_button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          onPressed: () => context.push('/lesson/${due.first}?review=1'),
          child: Semantics(
            label: 'نراجع',
            child: ExcludeSemantics(
              child: Text('🔁', style: TextStyle(fontSize: 32)),
            ),
          ),
        ),
      ),
    );
  }
}
