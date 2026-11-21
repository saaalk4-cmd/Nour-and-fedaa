import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/widgets/speak_on_open.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// العبارة المنطوقة عند فتح الشاشة (الطفلة لا تقرأ: تسمع وترى الشخصيتين).
const kWhoLearnsSay = 'من سيتعلم اليوم؟';

/// شاشة البداية: لافتة «نور وفداء»، الشخصيتان ولَمعة، وكارت لكل طفلة.
/// لمسة واحدة على الكارت = تدخل «عالمنا».
class WhoLearnsScreen extends ConsumerWidget {
  const WhoLearnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: ArtImage(Art.bgSky, fit: BoxFit.cover)),
          SafeArea(
            child: SpeakOnOpen(
              text: kWhoLearnsSay,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GlossyButton(
                          color: const Color(0xFFA463E8),
                          label: 'المقدمة',
                          icon: Icons.movie_creation_rounded,
                          size: 56,
                          onTap: () => context.push('/intro'),
                        ),
                        const Expanded(
                          child: Center(child: LogoSign(title: 'نُور وفداء', subtitle: 'عالم من التعلم والمغامرة')),
                        ),
                        // زر الأهل بكلمة واضحة تحته (البنات لا يقرأن، والقفل والرمز يحميانه).
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlossyButton(
                              color: const Color(0xFF3D8BEA),
                              label: 'لوحة ولي الأمر',
                              icon: Icons.lock_rounded,
                              size: 56,
                              onTap: () => context.push('/parent'),
                            ),
                            const SizedBox(height: 2),
                            const OutlineText('للأهل', size: 16, stroke: Color(0xFF1C5FA8), maxLines: 1),
                          ],
                        ),
                      ],
                    ),
                    const Expanded(child: _Characters()),
                    children.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => const Text('حدث خطأ، حاول مرة أخرى'),
                      data: (list) => ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 268),
                        child: SingleChildScrollView(
                          child: Column(
                        children: [
                          for (final c in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ChildCard(
                                child: c,
                                onTap: () async {
                                  ref.read(selectedChildIdProvider.notifier).state = c.id;
                                  await ref.read(voiceServiceProvider).sayAndWait(c.name);
                                  if (context.mounted) context.go('/world');
                                },
                              ),
                            ),
                        ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فداء ونور ولَمعة معًا فوق الكروت.
class _Characters extends StatelessWidget {
  const _Characters();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 5, child: ArtImage(Art.fedaaWelcome, fit: BoxFit.contain)),
        Expanded(flex: 4, child: ArtImage(Art.nourWelcome, fit: BoxFit.contain)),
        Expanded(
          flex: 3,
          child: Align(alignment: Alignment.topCenter, child: ArtImage(Art.lamaaWelcome, fit: BoxFit.contain)),
        ),
      ],
    );
  }
}

/// الشخصية المناسبة للعمر: الأصغر (≤4) نُور، والأكبر فداء.
String characterFor(Child c) => c.age <= 4 ? Art.nour : Art.fedaa;

/// لون الطفلة: نور أخضر، فداء وردي.
Color colorFor(Child c) => c.age <= 4 ? Kid.greenN : Kid.pinkF;

/// «سنة/سنتان/٣ سنوات…» بالعربية الصحيحة.
String ageLabel(int age) {
  if (age == 1) return 'سنة واحدة';
  if (age == 2) return 'سنتان';
  if (age >= 3 && age <= 10) return '$age سنوات';
  return '$age سنة';
}

/// كارت طفلة: صورة دائرية + الاسم + العمر + سهم (مثل التصميم المعتمد).
class ChildCard extends StatelessWidget {
  const ChildCard({super.key, required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KidPill(
      name: child.name,
      subtitle: ageLabel(child.age),
      art: characterFor(child),
      color: colorFor(child),
      onTap: onTap,
    );
  }
}
