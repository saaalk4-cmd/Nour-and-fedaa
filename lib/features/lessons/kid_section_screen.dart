import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/section_tile.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

const _palette = <Color>[
  Color(0xFF2A9D8F),
  Color(0xFFE76F8B),
  Color(0xFF6C7BD9),
  Color(0xFFE08E45),
  Color(0xFF4FAF8E),
  Color(0xFF58A6D8),
];

/// الاسم كما يُنطق: بلا رموز تعبيرية.
String spokenTitle(String title) => title
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
    .trim();

/// قسم فداء (5 سنوات): بطاقات صور كبيرة ناطقة بدل القوائم النصية.
/// تُنطق عبارة القسم عند الفتح، وعنوان الدرس عند الضغط ثم يبدأ الدرس الصوتي.
/// لا يُنطق هنا أي نص آية أو حديث: العنوان فقط، وعبر [Lesson.spokenText].
class KidSectionScreen extends ConsumerStatefulWidget {
  const KidSectionScreen({
    super.key,
    required this.category,
    required this.title,
    required this.child,
    this.parentView,
  });

  final String category;
  final String title;
  final Child child;

  /// شاشة النص الكاملة (المصدر والراوي والرقم) للأهل: بالضغط المطوّل على 📋.
  final WidgetBuilder? parentView;

  @override
  ConsumerState<KidSectionScreen> createState() => _KidSectionScreenState();
}

class _KidSectionScreenState extends ConsumerState<KidSectionScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceServiceProvider).speak(spokenTitle(widget.title));
    });
  }

  Future<void> _open(Lesson l) async {
    if (_busy) return;
    _busy = true;
    final say = l.spokenText(spokenTitle(l.title), step: true);
    if (say != null) unawaited(ref.read(voiceServiceProvider).speak(say));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) await context.push('/lesson/${l.id}');
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(widget.child.id)).valueOrNull ?? const <String>{};
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.parentView != null)
            GestureDetector(
              onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: widget.parentView!)),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('📋', style: TextStyle(fontSize: 22)),
              ),
            ),
        ],
      ),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل الدروس')),
        data: (all) {
          final mine = all.where((l) => l.category == widget.category && l.fitsAge(widget.child.age)).toList();
          if (mine.isEmpty) {
            return const Center(child: Text('🌟', style: TextStyle(fontSize: 96)));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: mine.length,
            itemBuilder: (_, i) => SectionTile(
              emoji: mine[i].emoji,
              title: spokenTitle(mine[i].title),
              color: _palette[i % _palette.length],
              emojiSize: 60,
              badge: done.contains(mine[i].id) ? '⭐' : null,
              onTap: () => _open(mine[i]),
            ),
          );
        },
      ),
    );
  }
}
