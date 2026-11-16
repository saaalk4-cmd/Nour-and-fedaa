import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../data/providers.dart';

/// شاشة البداية: شعار التطبيق ولَمعة وبطاقتان كبيرتان لاختيار من ستتعلم.
class WhoLearnsScreen extends ConsumerWidget {
  const WhoLearnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              const Mascot(size: 110),
              Text('نُور وفداء', style: AppText.display(52, color: AppColors.teal)),
              const SizedBox(height: 2),
              Text('من سيتعلم اليوم؟', style: AppText.display(26)),
              const SizedBox(height: 20),
              Expanded(
                child: children.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(child: Text('حدث خطأ، حاول مرة أخرى')),
                  data: (list) => ListView(
                    children: [
                      for (final c in list) ...[
                        _ChildCard(
                          name: c.name,
                          age: c.age,
                          small: c.age <= 4,
                          onTap: () {
                            ref.read(selectedChildIdProvider.notifier).state = c.id;
                            context.go('/home');
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/parent'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('لوحة ولي الأمر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.name,
    required this.age,
    required this.small,
    required this.onTap,
  });

  final String name;
  final int age;

  /// الأصغر (3–4): ألوان زرقاء/خضراء هادئة؛ الأكبر: وردي/بنفسجي.
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = small
        ? const [Color(0xFF4FC3D9), Color(0xFF2A9D8F)]
        : const [Color(0xFFFF8FB1), Color(0xFFB36AE0)];
    return PopTap(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              alignment: Alignment.center,
              child: const Text('👧', style: TextStyle(fontSize: 58)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(name, style: AppText.display(46, color: Colors.white)),
                  ),
                  Text(
                    '${'⭐' * (age > 5 ? 5 : age)}',
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
