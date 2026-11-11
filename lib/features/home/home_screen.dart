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
              return Center(child: ElevatedButton(onPressed: () => context.go('/'), child: const Text('اختاري من سيتعلم')));
            }
            final enabled = states.valueOrNull ?? const <String, bool>{};
            final visible = appSections.where((s) => enabled[s.id] ?? true).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('أهلًا يا ' + c.name + '! 🌟', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('مغامرة صغيرة اليوم... وخطوة جديدة في التعلم.', style: TextStyle(fontSize: 17)),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: () => context.push('/journey'), icon: const Icon(Icons.explore), label: const Text('ابدئي رحلتي')),
                const SizedBox(height: 18),
                Text('ماذا سنتعلم اليوم؟', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    for (final s in visible)
                      Material(
                        color: s.color,
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => context.push('/section/' + s.id),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.emoji, style: const TextStyle(fontSize: 44)),
                              const SizedBox(height: 8),
                              Text(s.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}