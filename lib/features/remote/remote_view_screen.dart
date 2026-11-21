import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import 'family_code.dart';
import 'remote_client.dart';
import 'remote_summary.dart';
import 'remote_sync.dart';

/// «المتابعة» على تليفون الأهل: آخر ملخص أرسله تليفون البنات. للقراءة فقط.
class RemoteViewScreen extends ConsumerStatefulWidget {
  const RemoteViewScreen({super.key});

  @override
  ConsumerState<RemoteViewScreen> createState() => _RemoteViewScreenState();
}

enum _Load { loading, ok, empty, offline, notLinked }

class _RemoteViewScreenState extends ConsumerState<RemoteViewScreen> {
  _Load _state = _Load.loading;
  RemoteDoc? _doc;
  FamilySummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _Load.loading);
    final code = await ref.read(settingsRepositoryProvider).familyCode();
    if (code == null) {
      if (mounted) setState(() => _state = _Load.notLinked);
      return;
    }
    try {
      final doc = await ref.read(remoteClientProvider).get(code);
      if (!mounted) return;
      if (doc == null) {
        setState(() => _state = _Load.empty);
        return;
      }
      setState(() {
        _doc = doc;
        _summary = FamilySummary.decode(doc.json);
        _state = _Load.ok;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _Load.offline);
    }
  }

  Future<void> _unlink() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إلغاء الربط'),
        content: const Text('التليفون ده هيرجع تطبيق عادي ومش هيفتح على المتابعة. تقدري تربطيه تاني بنفس الكود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الربط')),
        ],
      ),
    );
    if (yes != true) return;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDeviceRole('kids');
    await repo.setFamilyCode(null);
    ref
      ..invalidate(deviceRoleProvider)
      ..invalidate(familyCodeProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('متابعة البنات'),
        actions: [
          IconButton(tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'unlink' ? _unlink() : null,
            itemBuilder: (_) => const [PopupMenuItem(value: 'unlink', child: Text('إلغاء ربط التليفون ده'))],
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _message(String emoji, String title, String body) => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 60),
          Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('حاولي تاني'))),
        ],
      );

  Widget _body() {
    switch (_state) {
      case _Load.loading:
        return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
      case _Load.notLinked:
        return _message('🔗', 'التليفون مش مربوط', 'ادخلي لوحة الأهل واكتبي كود الأسرة من تليفون البنات.');
      case _Load.offline:
        return _message('📶', 'مفيش اتصال', 'اتأكدي إن تليفونك متصل بالنت وحاولي تاني.');
      case _Load.empty:
        return _message('⏳', 'لسه مفيش بيانات',
            'تليفون البنات هيبعت أول ما يتصل بالنت والتطبيق مفتوح. اتأكدي إن «إرسال التقدم» مشغّل في لوحة الأهل هناك.');
      case _Load.ok:
        final s = _summary!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Freshness(at: _doc!.updatedAt),
            for (final c in s.children) _ChildCard(c: c, limit: s.dailyLimitMin),
          ],
        );
    }
  }
}

String ago(DateTime at, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 2) return 'دلوقتي';
  if (d.inMinutes < 60) return 'من ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'من ${d.inHours} ساعة';
  return 'من ${d.inDays} يوم';
}

String minutes(int m) {
  if (m < 60) return '$m دقيقة';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h ساعة' : '$h ساعة و$r دقيقة';
}

class _Freshness extends StatelessWidget {
  const _Freshness({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final old = DateTime.now().difference(at) > const Duration(hours: 3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(old ? Icons.schedule_rounded : Icons.check_circle_rounded, color: old ? Colors.orange : Colors.green, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'آخر تحديث من تليفون البنات: ${ago(at)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.c, required this.limit});

  final ChildSummary c;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final where = c.week == null ? 'أنهت كل المهمات المتاحة 🎉' : 'الأسبوع ${c.week} · اليوم ${c.day}';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${c.name} (${c.age} سنين)', style: t.titleLarge)),
              Text('⭐ ${c.stars}', style: t.titleMedium),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip('⏱️ النهارده', limit > 0 ? '${minutes(c.todayMin)} من $limit' : minutes(c.todayMin)),
              _Chip('📚 الدروس', '${c.lessonsDone} من ${c.lessonsTotal}'),
              _Chip('🎮 مرات اللعب', '${c.gamePlays}'),
            ]),
            const SizedBox(height: 12),
            Text('📍 $where', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (c.nextLesson != null) Text('المهمة الجاية: ${c.nextLesson}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Text('آخر 7 أيام', style: t.titleSmall),
            const SizedBox(height: 6),
            _WeekBars(minutes: c.weekMin),
            if (c.recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('آخر الدروس', style: t.titleSmall),
              for (final r in c.recent)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${r.mastered ? '✅' : '🔁'} ${r.title}${r.at == null ? '' : ' · ${ago(r.at!)}'}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
            ],
            if (c.review.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('تستاهل نراجعها سوا', style: t.titleSmall),
              Text(c.review.join('، '), style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.minutes});

  final List<int> minutes;

  static const _days = ['أحد', 'اثنين', 'تلات', 'أربع', 'خميس', 'جمعة', 'سبت'];

  @override
  Widget build(BuildContext context) {
    if (minutes.isEmpty) return const SizedBox.shrink();
    final top = minutes.reduce((a, b) => a > b ? a : b).clamp(1, 100000);
    final today = DateTime.now();
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < minutes.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${minutes[i]}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  Container(
                    height: 4 + 44 * minutes[i] / top,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == minutes.length - 1 ? const Color(0xFF8F6BFF) : const Color(0xFFC9B8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _days[today.subtract(Duration(days: minutes.length - 1 - i)).weekday % 7],
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// يُستعمل في لوحة الأهل على تليفون الأهل: كتابة كود الأسرة.
Future<String?> askFamilyCode(BuildContext context) async {
  final ctl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('كود الأسرة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اكتبي الكود اللي ظاهر في لوحة الأهل على تليفون البنات.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            autofocus: true,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: 'XXXX-XXXX-XXXX-XXXX', errorText: error),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('رجوع')),
          FilledButton(
            onPressed: () {
              final code = FamilyCode.normalize(ctl.text);
              if (code == null) {
                setState(() => error = 'الكود 16 حرف/رقم، راجعيه');
              } else {
                Navigator.pop(c, code);
              }
            },
            child: const Text('ربط'),
          ),
        ],
      ),
    ),
  );
}
