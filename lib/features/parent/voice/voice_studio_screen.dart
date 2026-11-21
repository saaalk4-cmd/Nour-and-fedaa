import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/audio/user_voice_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import 'voice_catalog.dart';

/// «صوتي»: لوحة الأهل تسجّل الجمل بصوتها لتحل محل الصوت الآلي، وتسجّل نص الأحاديث بصوتها
/// (فلا يُقرأ حديث بصوت آلي أبدًا). التسجيلات على الجهاز فقط، ولها نسخة احتياطية يختارها الأهل.
class VoiceStudioScreen extends ConsumerStatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  ConsumerState<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _VoiceStudioScreenState extends ConsumerState<VoiceStudioScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _store = UserVoiceStore.instance;
  late final _voice = ref.read(voiceServiceProvider);
  Set<String> _have = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _store.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _store.revision.removeListener(_reload);
    _tabs.dispose();
    _voice.stop();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final k = await _store.keys();
      if (mounted) setState(() => _have = {...k});
    } catch (_) {
      // تعذّر قراءة المجلد: تبقى القائمة بلا علامات.
    }
  }

  Future<void> _backup(VoiceCatalog cat) async {
    final f = await _store.backup(cat.labels);
    if (!mounted) return;
    if (f == null) {
      _snack('لا توجد تسجيلات لحفظها بعد');
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'نسخة احتياطية من تسجيلات صوتي في «نُور وفداء»'));
    } catch (_) {
      _snack('تعذّرت المشاركة');
    }
  }

  Future<void> _restore() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['zip']);
      if (picked.isEmpty) return;
      final path = picked.first.path;
      if (path == null) return;
      final n = await _store.restore(await File(path).readAsBytes());
      ref.read(voiceServiceProvider).refreshSettings();
      _snack(n == 0 ? 'هذا الملف ليس نسخة احتياطية صالحة' : 'تم استرجاع $n تسجيلًا');
    } catch (_) {
      _snack('تعذّر استرجاع الملف');
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final cat = ref.watch(voiceCatalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('صوتي'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'نسخة احتياطية',
            onSelected: (v) async {
              final c = cat.valueOrNull;
              if (v == 'backup' && c != null) await _backup(c);
              if (v == 'restore') await _restore();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'backup', child: Text('حفظ نسخة احتياطية')),
              PopupMenuItem(value: 'restore', child: Text('استرجاع نسخة')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'الأساسية'), Tab(text: 'الأحاديث'), Tab(text: 'باقي الجمل')],
        ),
      ),
      body: cat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل قائمة الجمل')),
        data: (c) => Column(
          children: [
            _Intro(done: c.groups.fold(0, (n, g) => n + g.phrases.where((p) => _have.contains(p.key)).length), total: c.groups.fold(0, (n, g) => n + g.phrases.length)),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PhraseList(phrases: c.group('essential').phrases, have: _have),
                  _PhraseList(phrases: c.group('hadith').phrases, have: _have, hadith: true),
                  _PhraseList(
                    phrases: c.group('other').phrases,
                    have: _have,
                    query: _query,
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحثي عن جملة', border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4DA),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سجّلتِ $done من $total', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'صوتكِ يحل محل الصوت الآلي في كل مكان يقول الجملة. ما لم تسجّليه يبقى بالصوت الآلي. '
            'التسجيلات على هذا الموبايل فقط. سجّلي في مكان هادئ وقريبًا من الميكروفون.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PhraseList extends StatelessWidget {
  const _PhraseList({required this.phrases, required this.have, this.hadith = false, this.query = '', this.header});

  final List<VoicePhrase> phrases;
  final Set<String> have;
  final bool hadith;
  final String query;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final list = query.isEmpty ? phrases : [for (final p in phrases) if (p.text.contains(query)) p];
    return ListView.builder(
      itemCount: list.length + (header == null ? 0 : 1),
      itemBuilder: (context, i) {
        if (header != null && i == 0) return header!;
        final p = list[i - (header == null ? 0 : 1)];
        final done = have.contains(p.key);
        return ListTile(
          leading: Icon(done ? Icons.check_circle_rounded : Icons.mic_none_rounded, color: done ? const Color(0xFF3F8F2F) : AppColors.ink, size: 30),
          title: Text(
            hadith ? (p.title ?? p.text) : p.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: hadith ? Text(p.source ?? '', maxLines: 1, overflow: TextOverflow.ellipsis) : null,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => RecordSheet(phrase: p, hadith: hadith),
          ),
        );
      },
    );
  }
}

enum _Phase { idle, recording, review }

/// ورقة تسجيل جملة: سجّلي ← اسمعي ← احفظي أو أعيدي. (وللمسجَّلة: اسمعي، أعيدي، احذفي.)
class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key, required this.phrase, this.hadith = false});

  final VoicePhrase phrase;
  final bool hadith;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  final _store = UserVoiceStore.instance;
  AudioRecorder? _recorder;
  AudioRecorder get _rec => _recorder ??= AudioRecorder();
  StreamSubscription<Amplitude>? _amp;
  _Phase _phase = _Phase.idle;
  String? _temp;
  double _level = 0;
  bool _has = false;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _store.has(widget.phrase.key).then((v) {
      if (mounted) setState(() => _has = v);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _amp?.cancel();
    _recorder?.dispose();
    _store.stop();
    super.dispose();
  }

  Future<void> _start() async {
    await ref.read(voiceServiceProvider).stop();
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _msg = 'يلزم السماح بالميكروفون من إعدادات الموبايل');
        return;
      }
      final path = await _store.tempPath();
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
          // تنقية الضوضاء وضبط علو الصوت تلقائيًا
          autoGain: true,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: path,
      );
      _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        if (mounted) setState(() => _level = ((a.current + 50) / 50).clamp(0.0, 1.0));
      });
      setState(() {
        _phase = _Phase.recording;
        _temp = path;
        _msg = null;
      });
    } catch (_) {
      setState(() => _msg = 'تعذّر بدء التسجيل');
    }
  }

  Future<void> _stop() async {
    try {
      final path = await _rec.stop();
      await _amp?.cancel();
      _amp = null;
      final f = path == null ? null : File(path);
      if (f == null || !await f.exists() || await f.length() < 1500) {
        setState(() {
          _phase = _Phase.idle;
          _level = 0;
          _msg = 'التسجيل قصير جدًا، حاولي مرة ثانية';
        });
        return;
      }
      setState(() {
        _temp = path;
        _phase = _Phase.review;
        _level = 0;
      });
    } catch (_) {
      setState(() {
        _phase = _Phase.idle;
        _msg = 'تعذّر إيقاف التسجيل';
      });
    }
  }

  Future<void> _preview() async {
    final t = _temp;
    if (t == null) return;
    setState(() => _busy = true);
    await _store.playFile(t);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _playSaved() async {
    setState(() => _busy = true);
    await _store.playAndWait(widget.phrase.key);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    final t = _temp;
    if (t == null) return;
    await _store.save(widget.phrase.key, t);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ صوتكِ')));
  }

  Future<void> _delete() async {
    await _store.delete(widget.phrase.key);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.phrase;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hadith) ...[
              Text(p.title ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${p.narrator ?? ''}\n${p.source ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('اقرئي الحديث كما هو مكتوب بالضبط، بلا زيادة ولا نقص:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFFF4DA), borderRadius: BorderRadius.circular(18)),
              child: Text(
                p.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: widget.hadith ? 26 : 24, height: 1.7, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 14),
            if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_msg!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB3261E)))),
            if (_phase == _Phase.recording) ...[
              LinearProgressIndicator(value: _level, minHeight: 10, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _stop,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), minimumSize: const Size.fromHeight(56)),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('إيقاف التسجيل'),
              ),
            ] else if (_phase == _Phase.review) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('اسمعي ما سجّلتِ'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _start, child: const Text('إعادة'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: _save, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3F8F2F)), child: const Text('حفظ'))),
                ],
              ),
            ] else ...[
              if (_has) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _playSaved,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('اسمعي تسجيلكِ الحالي'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _start,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), minimumSize: const Size.fromHeight(56)),
                icon: const Icon(Icons.mic_rounded),
                label: Text(_has ? 'سجّلي من جديد' : 'ابدئي التسجيل'),
              ),
              if (_has) TextButton(onPressed: _delete, child: const Text('حذف تسجيلي (يعود الصوت الآلي)')),
            ],
          ],
        ),
      ),
    );
  }
}
