import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/mascot.dart';
import '../../data/content/curriculum.dart';
import '../../data/content/lesson.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

final curriculumProvider = FutureProvider<Curriculum>((ref) {
  return CurriculumRepository().load();
});

String _emojiFor(Lesson l) {
  switch (l.category) {
    case 'quran':
    case 'prophets':
      return '📖';
    case 'akhlaq':
      return '❤️';
    case 'adhkar':
    case 'prayer':
      return '🕌';
    default:
      return l.emoji;
  }
}

/// «رحلتي اليوم»: 3–5 مغامرات قصيرة فقط، تتقدم حسب إنجاز الطفلة لا حسب التاريخ.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// اليوم الذي فُتحت عليه الشاشة؛ إن تغيّر بعد الإكمال نحتفل بإنهاء اليوم.
  String? _openedDayKey;
  String? _spokenKey;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلتي اليوم 🌟'),
        actions: [
          IconButton(
            tooltip: 'خريطة الرحلة',
            icon: const Icon(Icons.explore),
            onPressed: () => context.push('/journey'),
          ),
        ],
      ),
      body: child.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('حدث خطأ')),
        data: (c) => c == null
            ? const Center(child: Text('اختاري طفلة أولًا'))
            : _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, Child c) {
    final curriculum = ref.watch(curriculumProvider);
    final lessons = ref.watch(lessonsProvider);
    final done = ref.watch(completedLessonIdsProvider(c.id));
    if (curriculum.isLoading || lessons.isLoading || done.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (curriculum.hasError || lessons.hasError || done.hasError) {
      return const Center(child: Text('تعذر تحميل الرحلة'));
    }
    final plan = curriculum.requireValue.planFor(
      childAge: c.age,
      allLessons: lessons.requireValue,
      completed: done.requireValue,
    );
    final key = plan.finishedAll ? 'all' : '${plan.week!.week}-${plan.day!.day}';
    _openedDayKey ??= key;
    final justFinishedDay = _openedDayKey != key;
    final little = c.ageGroup == AgeGroup.early;

    // الطفلة قد تكون وحدها: نرحّب بها صوتيًا مرة لكل يوم.
    if (_spokenKey != key) {
      _spokenKey = key;
      final text = justFinishedDay
          ? 'أحسنتِ يا ${c.name}! أكملتِ رحلة اليوم'
          : (plan.finishedAll
              ? 'أحسنتِ يا ${c.name}! أكملتِ كل المغامرات'
              : 'أهلًا يا ${c.name}! هيا نبدأ مغامرات اليوم');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(voiceServiceProvider).speak(text),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Mascot(size: little ? 110 : 84, mood: justFinishedDay ? MascotMood.cheer : MascotMood.happy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                justFinishedDay
                    ? '🎁 أكملتِ رحلة اليوم يا ${c.name}!\nهذه رحلة جديدة لكِ.'
                    : 'مغامرات اليوم يا ${c.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (plan.finishedAll)
          const _AllDoneCard()
        else ...[
          Text(
            'الأسبوع ${plan.week!.week}: ${plan.week!.title}\nاليوم ${plan.day!.day} — ${plan.day!.title}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: plan.doneCount / plan.adventures.length,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text('${plan.doneCount} من ${plan.adventures.length} مغامرات ⭐'),
          const SizedBox(height: 16),
          for (final l in plan.adventures)
            _AdventureCard(
              lesson: l,
              done: done.requireValue.contains(l.id),
              little: little,
            ),
        ],
      ],
    );
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({required this.lesson, required this.done, required this.little});

  final Lesson lesson;
  final bool done;
  final bool little;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: done ? const Color(0xFFEAF6EE) : Colors.white,
        elevation: done ? 0 : 1,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.push('/lesson/${lesson.id}'),
          child: Padding(
            padding: EdgeInsets.all(little ? 22 : 18),
            child: Row(
              children: [
                Text(_emojiFor(lesson), style: TextStyle(fontSize: little ? 54 : 42)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: TextStyle(fontSize: little ? 23 : 20, fontWeight: FontWeight.w800),
                      ),
                      Text(done ? 'أكملتِها ✨' : 'مغامرة قصيرة'),
                    ],
                  ),
                ),
                if (done)
                  const Text('✅', style: TextStyle(fontSize: 28))
                else
                  const Icon(Icons.play_circle_fill, size: 42),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '🏆 أكملتِ كل مغامرات المنهج المتاح الآن!\nمغامرات جديدة قادمة قريبًا إن شاء الله.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, height: 1.6),
        ),
      ),
    );
  }
}
