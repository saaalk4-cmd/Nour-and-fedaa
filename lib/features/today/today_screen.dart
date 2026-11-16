import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.75),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
              ),
              child: Mascot(size: little ? 100 : 80, mood: justFinishedDay ? MascotMood.cheer : MascotMood.happy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Text(
                  justFinishedDay
                      ? '🎁 أكملتِ رحلة اليوم يا ${c.name}!\nهذه رحلة جديدة لكِ.'
                      : 'مغامرات اليوم يا ${c.name}',
                  style: AppText.display(22),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (plan.finishedAll)
          const _AllDoneCard()
        else ...[
          if (!little)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الأسبوع ${plan.week!.week}: ${plan.week!.title}  •  اليوم ${plan.day!.day} — ${plan.day!.title}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
          const SizedBox(height: 12),
          _StarTrail(done: plan.doneCount, total: plan.adventures.length),
          const SizedBox(height: 18),
          for (var i = 0; i < plan.adventures.length; i++)
            _AdventureCard(
              index: i + 1,
              lesson: plan.adventures[i],
              done: done.requireValue.contains(plan.adventures[i].id),
              little: little,
            ),
        ],
      ],
    );
  }
}

/// نجوم التقدم: مضيئة للمنجز ورمادية للباقي (صور بدل أرقام وشرائط).
class _StarTrail extends StatelessWidget {
  const _StarTrail({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedScale(
            scale: i < done ? 1.15 : 0.9,
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.star_rounded,
                size: 46,
                color: i < done ? AppColors.sun : const Color(0xFFD5DCE3),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({
    required this.index,
    required this.lesson,
    required this.done,
    required this.little,
  });

  final int index;
  final Lesson lesson;
  final bool done;
  final bool little;

  static const _colors = <Color>[
    Color(0xFF2A9D8F),
    Color(0xFFE76F8B),
    Color(0xFF6C7BD9),
    Color(0xFFE08E45),
    Color(0xFF4FAF8E),
  ];

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.leaf : _colors[(index - 1) % _colors.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PopTap(
        onTap: () => context.push('/lesson/${lesson.id}'),
        child: Container(
          padding: EdgeInsets.all(little ? 18 : 14),
          decoration: BoxDecoration(
            color: done ? const Color(0xFFEAF6EE) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                width: little ? 84 : 68,
                height: little ? 84 : 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                ),
                child: Text(_emojiFor(lesson), style: TextStyle(fontSize: little ? 46 : 36)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(little ? 25 : 22),
                    ),
                    if (!little)
                      Text(
                        done ? 'أكملتِها ✨' : 'مغامرة $index',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7A89)),
                      ),
                  ],
                ),
              ),
              if (done)
                const Text('⭐', style: TextStyle(fontSize: 34))
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(colors: [Color(0xFFFFD66B), Color(0xFFFFA24D)]),
        boxShadow: const [BoxShadow(color: Color(0x44FFA24D), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 8),
          Text(
            'أكملتِ كل مغامرات المنهج المتاح الآن!',
            textAlign: TextAlign.center,
            style: AppText.display(26, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'مغامرات جديدة قادمة قريبًا إن شاء الله.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
