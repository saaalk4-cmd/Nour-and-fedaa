import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

class WhoLearnsScreen extends ConsumerWidget {
  const WhoLearnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('نُور وفداء 🌟',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('من سيتعلم اليوم؟',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 32),
              Expanded(
                child: children.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      const Center(child: Text('حدث خطأ، حاول مرة أخرى')),
                  data: (list) => ListView(
                    children: [
                      for (final c in list) ...[
                        _ChildButton(
                          label: '👧 ${c.name} — ${c.age} سنوات',
                          color: c.age >= 5 ? AppColors.rose : AppColors.teal,
                          onTap: () {
                            ref.read(selectedChildIdProvider.notifier).state =
                                c.id;
                            context.go('/home');
                          },
                        ),
                        const SizedBox(height: 20),
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

class _ChildButton extends StatelessWidget {
  const _ChildButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
