import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import 'sections.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final states = ref.watch(sectionStatesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'تغيير الطفلة',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            ref.read(selectedChildIdProvider.notifier).state = null;
            context.go('/');
          },
        ),
        title: const Text('نُور وفداء 🌟'),
      ),
      body: SafeArea(
        child: child.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('حدث خطأ')),
          data: (c) {
            if (c == null) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('اختاري من سيتعلم'),
                ),
              );
            }
            final enabled = states.valueOrNull ?? const <String, bool>{};
            final visible =
                appSections.where((s) => enabled[s.id] ?? true).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text('ماذا سنتعلم اليوم يا ${c.name}؟',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('⭐ ${c.stars}   •   المستوى ${c.level}',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        for (final s in visible)
                          _SectionTile(
                            section: s,
                            onTap: () => context.push('/section/${s.id}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.onTap});

  final AppSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: section.color,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(section.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              section.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
