import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'game_content.dart';
import 'game_packs.dart';
import 'game_repository.dart';

final gameRepositoryProvider = Provider((_) => GameRepository());

final gamePackServiceProvider = Provider((ref) => GamePackService(ref.watch(settingsRepositoryProvider)));

/// كل الألعاب: المضمّنة في التطبيق + الحزمة المنزّلة سابقًا (إن وُجدت).
final gameCatalogProvider = FutureProvider<GameCatalog>((ref) async {
  final base = GameCatalog.parse(await rootBundle.loadString(GameCatalog.asset));
  final pack = await ref.watch(gamePackServiceProvider).saved();
  return pack == null ? base : base.merge(pack);
});

/// تقدم طفلة في الألعاب: game_id → (level_key → best_stars).
final gameProgressProvider = FutureProvider.family<Map<String, Map<String, int>>, int>(
  (ref, childId) => ref.watch(gameRepositoryProvider).progress(childId),
);

/// هل المستوى مفتوح؟ الأول دائمًا، وكل مستوى بعد أن تجمع الطفلة نجوم المستوى السابق.
bool levelUnlocked(GameTrack track, Map<String, int> best, int i) {
  if (i == 0) return true;
  final prev = track.levels[i - 1];
  return (best[prev.key] ?? 0) >= prev.passStars;
}

/// نجوم اللعبة كلها لهذه الطفلة (مجموع أفضل نتيجة لكل مستوى).
int gameStars(GameTrack track, Map<String, int> best) =>
    track.levels.fold(0, (s, l) => s + (best[l.key] ?? 0));

int gameMaxStars(GameTrack track) => track.levels.fold(0, (s, l) => s + l.rounds);
