import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/quran.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../quran/hifz.dart';
import '../quran/hifz_screens.dart';
import '../quran/quran_screen.dart' show quranContentProvider;

/// للأهل: تعديل محفوظ البنت (سورة بسورة) ومن أين يبدأ الحفظ الجديد.
class HifzEditScreen extends ConsumerStatefulWidget {
  const HifzEditScreen({super.key, required this.childId});

  final int childId;

  @override
  ConsumerState<HifzEditScreen> createState() => _HifzEditScreenState();
}

class _HifzEditScreenState extends ConsumerState<HifzEditScreen> {
  HifzProgress? _p;
  Child? _child;

  Future<void> _load(Child c) async {
    final p = await ref.read(hifzRepositoryProvider).load(childId: c.id, name: c.name, age: c.age);
    if (mounted) setState(() => _p = p);
  }

  Future<void> _save() async {
    final c = _child;
    final p = _p;
    if (c == null || p == null) return;
    await ref.read(hifzRepositoryProvider).save(c.id, p);
    ref.invalidate(hifzProvider(c));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider).valueOrNull;
    final content = ref.watch(quranContentProvider).valueOrNull;
    final c = children?.where((x) => x.id == widget.childId).firstOrNull;
    if (c != null && _child == null) {
      _child = c;
      _load(c);
    }
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: Text(c == null ? 'الحفظ' : 'حفظ ${c.name}')),
      body: (c == null || p == null || content == null)
          ? const Center(child: CircularProgressIndicator())
          : _body(c, p, content),
    );
  }

  Widget _body(Child c, HifzProgress p, QuranContent q) {
    final surahs = [
      for (final j in juzFor(c))
        ...q.surahs.where((s) => juzOfSurah(s.surahNumber) == j).toList()
          ..sort((a, b) => b.surahNumber.compareTo(a.surahNumber)),
    ];
    String name(int n) => q.surahs.firstWhere((s) => s.surahNumber == n).name;
    final next = p.nextNew(q);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (p.newOrder.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الحفظ الجديد (3 آيات يوميًا)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    next == null
                        ? 'أنهت كل سور الحفظ الجديد 🎉'
                        : 'الآن: سورة ${name(next.surah)} من الآية ${next.from}',
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    key: const ValueKey('hifz-start'),
                    isExpanded: true,
                    hint: const Text('ابدئي الجديد من سورة…'),
                    value: null,
                    items: [
                      for (final s in p.newOrder) DropdownMenuItem(value: s, child: Text('سورة ${name(s)} (من أولها)')),
                    ],
                    onChanged: (s) {
                      if (s == null) return;
                      p.setNewStart(s);
                      _save();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('علّمي على السور المحفوظة: تدخل المراجعة اليومية بالدور.', style: TextStyle(fontSize: 15)),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final s in surahs)
                CheckboxListTile(
                  key: ValueKey('hifz-${s.surahNumber}'),
                  value: p.memorized.contains(s.surahNumber),
                  title: Text('${s.surahNumber}. ${s.name}'),
                  subtitle: Text('${juzName(juzOfSurah(s.surahNumber)!)} · ${s.ayahs.length} آية'
                      '${s.surahNumber == p.currentSurah ? ' · تحفظها الآن' : ''}'),
                  onChanged: (v) {
                    p.setMemorized(s.surahNumber, v ?? false);
                    _save();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
