import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../core/design/pop_tap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_on_open.dart';
import '../../data/providers.dart';
import 'game_providers.dart';

/// رفوف الألعاب (كل رف = مجال تعليمي).
class GameShelf {
  const GameShelf(this.id, this.title, this.emoji, this.color);
  final String id;
  final String title;
  final String emoji;
  final Color color;
}

const gameShelves = <GameShelf>[
  GameShelf('quran', 'القرآن', '📖', Color(0xFF2A9D8F)),
  GameShelf('prayer', 'الوضوء والصلاة', '🕌', Color(0xFF4CB944)),
  GameShelf('adhkar', 'الأذكار', '🤲', Color(0xFF6C7BD9)),
  GameShelf('akhlaq', 'الآداب', '❤️', Color(0xFFE76F8B)),
  GameShelf('letters', 'الحروف والكلمات', '🔤', Color(0xFFE08E45)),
  GameShelf('numbers', 'الأرقام', '🔢', Color(0xFF58A6D8)),
  GameShelf('colors', 'الألوان والأشكال', '🎨', Color(0xFFF2A93B)),
  GameShelf('focus', 'الذاكرة والملاحظة', '🧠', Color(0xFFA463E8)),
];

GameShelf shelfOf(String id) => gameShelves.firstWhere((s) => s.id == id, orElse: () => gameShelves.last);

const kGamesSay = 'اختاري لعبة';

/// «الألعاب»: رفوف ملوّنة لكل مجال، وكل لعبة بطاقة بنجومها. تُحدَّث الحزمة الإضافية بهدوء عند وجود إنترنت.
class GamesHomeScreen extends ConsumerStatefulWidget {
  const GamesHomeScreen({super.key});

  @override
  ConsumerState<GamesHomeScreen> createState() => _GamesHomeScreenState();
}

class _GamesHomeScreenState extends ConsumerState<GamesHomeScreen> {
  String _shelf = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(voiceServiceProvider).sayAndWait(kGamesSay);
      // «نزّلي مرة والعبي على طول»: نحاول تحديث الحزمة الإضافية بهدوء.
      if ((await ref.read(settingsRepositoryProvider).packMode()) != 'auto') return;
      final updated = await ref.read(gamePackServiceProvider).refresh();
      if (updated && mounted) ref.invalidate(gameCatalogProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider).valueOrNull;
    final catalog = ref.watch(gameCatalogProvider);
    final progress = child == null ? null : ref.watch(gameProgressProvider(child.id)).valueOrNull;
    return KidScaffold(
      title: 'الألعاب',
      background: Art.bgCastle,
      onBack: () => context.canPop() ? context.pop() : context.go('/world'),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: ParchmentCard(child: Text('تعذر تحميل الألعاب'))),
        data: (cat) {
          if (child == null) return const SizedBox.shrink();
          final shelves = [
            for (final s in gameShelves)
              if (cat.games.any((g) => g.section == s.id && g.fitsAge(child.age))) s,
          ];
          final games = [
            for (final g in cat.games)
              if (g.fitsAge(child.age) && (_shelf == 'all' || g.section == _shelf)) g,
          ];
          return Column(
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _Chip(label: 'الكل', emoji: '🌟', color: const Color(0xFFFFB300), on: _shelf == 'all', onTap: () => setState(() => _shelf = 'all')),
                    for (final s in shelves)
                      _Chip(
                        label: s.title,
                        emoji: s.emoji,
                        color: s.color,
                        on: _shelf == s.id,
                        onTap: () {
                          setState(() => _shelf = s.id);
                          ref.read(voiceServiceProvider).speak(s.title);
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: games.length,
                  itemBuilder: (_, i) {
                    final g = games[i];
                    final track = g.trackFor(child.age);
                    final best = progress?[g.id] ?? const <String, int>{};
                    final got = gameStars(track, best);
                    final max = gameMaxStars(track);
                    return WorldTile(
                      emoji: g.emoji,
                      title: g.title,
                      subtitle: got == 0 ? shelfOf(g.section).title : '⭐ $got من $max',
                      color: shelfOf(g.section).color,
                      badge: got >= max && max > 0,
                      onTap: () async {
                        await ref.read(voiceServiceProvider).sayAndWait(g.title);
                        if (context.mounted) await context.push('/games/${g.id}');
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.emoji, required this.color, required this.on, required this.onTap});

  final String label;
  final String emoji;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 6, bottom: 6),
      child: PopTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? color : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: on ? Colors.white : color, width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Text('$emoji $label', style: AppText.display(19, color: on ? Colors.white : Color.lerp(color, Colors.black, 0.35)!)),
        ),
      ),
    );
  }
}

/// المستويات: نسخة الطفلة (فداء: سهل/متوسط/متقدم، نور: مستوى 1/2/3) بنجومها وأقفالها.
class GameLevelsScreen extends ConsumerWidget {
  const GameLevelsScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider).valueOrNull;
    final cat = ref.watch(gameCatalogProvider).valueOrNull;
    final g = cat?.byId(gameId);
    if (child == null || g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final track = g.trackFor(child.age);
    final best = ref.watch(gameProgressProvider(child.id)).valueOrNull?[g.id] ?? const <String, int>{};
    final shelf = shelfOf(g.section);
    return SpeakOnOpen(
      text: g.intro ?? g.title,
      child: KidScaffold(
      title: g.title,
      background: Art.weekBackgrounds[g.title.length % Art.weekBackgrounds.length],
      onBack: () => context.canPop() ? context.pop() : context.go('/games'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: shelf.color, width: 5)),
                child: Text(g.emoji, style: const TextStyle(fontSize: 52)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ParchmentCard(
                  child: Text(g.intro ?? 'اختاري مستوى', style: const TextStyle(fontSize: 18, height: 1.3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < track.levels.length; i++) ...[
            Builder(builder: (context) {
              final lv = track.levels[i];
              final open = levelUnlocked(track, best, i);
              return WoodSign(
                icon: Text(open ? const ['🌱', '🌿', '🌳', '🏆'][i.clamp(0, 3)] : '🔒'),
                title: lv.title,
                subtitle: open ? (lv.sub ?? '${lv.rounds} جولات') : 'اجمعي نجوم المستوى السابق أولًا',
                onTap: () async {
                  final voice = ref.read(voiceServiceProvider);
                  if (!open) {
                    await voice.sayAndWait('اجمعي نجوم المستوى السابق أولًا');
                    return;
                  }
                  await voice.sayAndWait(lv.title);
                  if (context.mounted) await context.push('/games/${g.id}/play/${lv.key}');
                },
              );
            }),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: StarRow(filled: best[track.levels[i].key] ?? 0, total: track.levels[i].rounds, size: 24),
            ),
          ],
          if (g.goal != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('للأهل: ${g.goal}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Wood.text)),
            ),
        ],
      ),
    ));
  }
}
