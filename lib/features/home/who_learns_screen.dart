import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/art.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_on_open.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// العبارة المنطوقة عند فتح الشاشة (الطفلة لا تقرأ: تسمع وترى الشخصيتين).
const kWhoLearnsSay = 'من سيتعلم اليوم؟';

/// شاشة البداية: لَمعة وبطاقتان كبيرتان بصورة الشخصيتين. لمسة واحدة = تبدأ الرحلة.
class WhoLearnsScreen extends ConsumerWidget {
  const WhoLearnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'intro',
        tooltip: 'المقدمة',
        backgroundColor: Colors.white70,
        elevation: 0,
        onPressed: () => context.push('/intro'),
        child: const Text('🎬', style: TextStyle(fontSize: 20)),
      ),
      body: SafeArea(
        child: SpeakOnOpen(
          text: kWhoLearnsSay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                const ArtImage(Art.lamaa, height: 104),
                Text('نُور وفداء', style: AppText.display(46, color: AppColors.teal)),
                const SizedBox(height: 10),
                Expanded(
                  child: children.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const Center(child: Text('حدث خطأ، حاول مرة أخرى')),
                    data: (list) {
                      Widget card(Child c) => ChildCard(
                            child: c,
                            onTap: () async {
                              ref.read(selectedChildIdProvider.notifier).state = c.id;
                              unawaited(ref.read(voiceServiceProvider).speak(c.name));
                              await Future<void>.delayed(const Duration(milliseconds: 700));
                              if (context.mounted) context.go('/path');
                            },
                          );
                      if (list.length <= 2) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: Row(
                              children: [
                                for (final c in list)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: card(c),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                        children: [for (final c in list) card(c)],
                      );
                    },
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
      ),
    );
  }
}

/// الشخصية المناسبة للعمر: الأصغر (≤4) نُور، والأكبر فداء.
String characterFor(Child c) => c.age <= 4 ? Art.nour : Art.fedaa;

/// بطاقة طفلة: صورة الشخصية كبيرة + الاسم. لا كلام آخر.
class ChildCard extends StatelessWidget {
  const ChildCard({super.key, required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final little = child.age <= 4;
    final colors = little
        ? const [Color(0xFFB6F0A6), Kid.greenN]
        : const [Color(0xFFFFC2D6), Kid.pinkF];
    return Semantics(
      button: true,
      label: child.name,
      child: PopTap(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Kid.radiusL),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: ArtImage(characterFor(child), fit: BoxFit.contain),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Kid.radiusL - 5)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(child.name, style: AppText.display(40, color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
