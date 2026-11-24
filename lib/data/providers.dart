import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/child.dart';
import 'models/parent_account.dart';
import 'repositories/account_repository.dart';
import 'repositories/child_repository.dart';
import 'repositories/settings_repository.dart';

final childRepositoryProvider = Provider((_) => ChildRepository());
final settingsRepositoryProvider = Provider((_) => SettingsRepository());

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => LocalAccountRepository(ref.watch(settingsRepositoryProvider)),
);

final accountProvider = FutureProvider<ParentAccount?>(
  (ref) => ref.watch(accountRepositoryProvider).current(),
);

final childrenProvider = FutureProvider<List<Child>>(
  (ref) => ref.watch(childRepositoryProvider).all(),
);

/// الطفل المختار حاليًا (null = لم يُختر بعد).
final selectedChildIdProvider = StateProvider<int?>((_) => null);

final selectedChildProvider = FutureProvider<Child?>((ref) async {
  final id = ref.watch(selectedChildIdProvider);
  if (id == null) return null;
  return ref.watch(childRepositoryProvider).byId(id);
});

final sectionStatesProvider = FutureProvider<Map<String, bool>>(
  (ref) => ref.watch(settingsRepositoryProvider).sectionStates(),
);

/// بيانات الطفل أثناء رحلة التسجيل.
final childDraftProvider = StateProvider<ChildDraft>((_) => const ChildDraft());
