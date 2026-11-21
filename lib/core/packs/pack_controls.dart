import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// أسماء الحزم كما تراها الأم.
String packTitle(String name) => switch (name) {
      'voice' => 'أصوات الدروس',
      'quran_30' => 'جزء عمّ',
      'quran_29' => 'جزء تبارك',
      'quran_28' => 'جزء قد سمع',
      _ => name,
    };

String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجا';

/// لوحة الأهل: «الأصوات والقرآن الإضافية» — تنزّل مرة واحدة وتُحفظ للعمل بلا نت.
class PackControls extends ConsumerWidget {
  const PackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(packDownloaderProvider);
    final auto = ref.watch(packAutoProvider).valueOrNull ?? true;
    final wifi = ref.watch(packWifiOnlyProvider).valueOrNull ?? true;
    final repo = ref.read(settingsRepositoryProvider);
    final dl = ref.read(packDownloaderProvider.notifier);
    return Column(
      children: [
        const ListTile(
          leading: Text('📦', style: TextStyle(fontSize: 26)),
          title: Text('بتتنزّل مرة واحدة وتتحفظ'),
          subtitle: Text('جمل دروس فداء الطويلة وأجزاء القرآن بصوت المنشاوي. بعد التنزيل بتشتغل من غير نت.'),
        ),
        for (final p in st.available)
          ListTile(
            dense: true,
            leading: Icon(st.upToDate(p) ? Icons.check_circle_rounded : Icons.downloading_rounded,
                color: st.upToDate(p) ? Colors.green : Colors.orange),
            title: Text(packTitle(p.name)),
            subtitle: Text(st.upToDate(p) ? 'متنزّل (${mb(p.bytes)})' : 'لسه (${mb(p.bytes)})'),
          ),
        if (st.busy && st.current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('بيتنزّل: ${packTitle(st.current!)} — ${mb(st.received)} من ${mb(st.total)}'),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: st.progress, minHeight: 8),
              ],
            ),
          ),
        if (st.message != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(st.message!)),
        SwitchListTile(
          title: const Text('تنزيل تلقائي'),
          subtitle: const Text('أول ما التطبيق يلاقي نت'),
          value: auto,
          onChanged: (v) async {
            await repo.setPackAuto(v);
            ref.invalidate(packAutoProvider);
          },
        ),
        SwitchListTile(
          title: const Text('على الواي فاي بس'),
          subtitle: const Text('علشان باقة الموبايل'),
          value: wifi,
          onChanged: (v) async {
            await repo.setPackWifiOnly(v);
            ref.invalidate(packWifiOnlyProvider);
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_rounded),
          title: const Text('نزّلي دلوقتي'),
          enabled: !st.busy,
          onTap: () => dl.run(manual: true),
        ),
      ],
    );
  }
}

/// يبدأ التنزيل بهدوء بعد فتح التطبيق بقليل (على تليفون البنات فقط).
Future<void> startPacksSoon(WidgetRef ref, {Duration after = const Duration(seconds: 20)}) async {
  await Future<void>.delayed(after);
  try {
    if (await ref.read(settingsRepositoryProvider).deviceRole() != 'kids') return;
  } catch (_) {
    return;
  }
  await ref.read(packDownloaderProvider.notifier).run();
}
