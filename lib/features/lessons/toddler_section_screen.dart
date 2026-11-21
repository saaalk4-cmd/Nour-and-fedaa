import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import 'kid_section_screen.dart' show spokenTitle;
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// قسم الصغيرات (3–4 سنوات): بطاقات صور كبيرة، بلا نصوص طويلة ولا مصادر.
/// الضغط على البطاقة يفتح الدرس بواجهة «صورة + صوت + لمس».
const _palette = <Color>[
  Color(0xFF2A9D8F),
  Color(0xFFE76F8B),
  Color(0xFF6C7BD9),
  Color(0xFFE08E45),
  Color(0xFF4FAF8E),
  Color(0xFF58A6D8),
];

class ToddlerSectionScreen extends ConsumerWidget {
  const ToddlerSectionScreen({super.key, required this.category, required this.title, required this.child});

  final String category;
  final String title;
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(child.id)).valueOrNull ?? const <String>{};
    // اسم القسم يُقال عند الضغط عليه قبل الفتح، فلا نكرره هنا.
    return KidScaffold(
      title: title,
      background: SectionLook.of(category).background,
      onBack: () => context.canPop() ? context.pop() : context.go('/world'),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل الدروس')),
        data: (all) {
          final mine = all.where((l) => l.category == category && l.fitsAge(child.age)).toList();
          if (mine.isEmpty) {
            return const Center(child: Text('🌟', style: TextStyle(fontSize: 96)));
          }
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
            children: [
              for (var i = 0; i < mine.length; i++)
                _PictureCard(
                  lesson: mine[i],
                  done: done.contains(mine[i].id),
                  color: _palette[i % _palette.length],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PictureCard extends ConsumerStatefulWidget {
  const _PictureCard({required this.lesson, required this.done, required this.color});

  final Lesson lesson;
  final bool done;
  final Color color;

  @override
  ConsumerState<_PictureCard> createState() => _PictureCardState();
}

class _PictureCardState extends ConsumerState<_PictureCard> {
  bool _busy = false;

  /// يفتح الدرس (والدرس يبدأ بقول اسمه).
  Future<void> _open() async {
    if (_busy) return;
    _busy = true;
    try {
      final l = widget.lesson;
      // نور تسمع اسم الدرس عند الضغط على الصورة، ثم يُفتح الدرس (ويقول اسمه مرة ثانية أول ما يفتح).
      final voice = ref.read(voiceServiceProvider);
      final name = l.spokenText(spokenTitle(l.title), step: true);
      if (name != null) {
        await voice.sayAndWait(name, max: const Duration(seconds: 6));
      } else {
        await voice.stop();
      }
      if (mounted) await context.push('/lesson/${l.id}');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorldTile(
      emoji: widget.lesson.emoji,
      title: spokenTitle(widget.lesson.title),
      color: widget.color,
      emojiSize: 60,
      badge: widget.done,
      onTap: _open,
    );
  }
}
