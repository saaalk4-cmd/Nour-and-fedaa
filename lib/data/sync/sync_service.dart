import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/child_repository.dart';
import '../repositories/settings_repository.dart';
import 'child_snapshot.dart';
import 'cloud_store.dart';

/// مزامنة بيانات الأسرة مع السحابة. التطبيق يعمل محليًا دائمًا، والمزامنة
/// نسخة احتياطية ونقل بين الأجهزة: أي فشل (لا إنترنت مثلًا) لا يوقف شيئًا.
class SyncService {
  SyncService({
    required this.uid,
    required this.store,
    ChildSnapshot? snapshot,
    ChildRepository? children,
    SettingsRepository? settings,
  })  : _snap = snapshot ?? ChildSnapshot(),
        _children = children ?? ChildRepository(),
        _settings = settings ?? SettingsRepository();

  final String uid;
  final CloudStore store;
  final ChildSnapshot _snap;
  final ChildRepository _children;
  final SettingsRepository _settings;

  Future<void> pushChild(int childId) async {
    final data = await _snap.export(childId);
    if (data == null) return;
    await store.saveChild(uid, data['cloud_id'] as String, data);
  }

  Future<void> deleteChild(String cloudId) => store.deleteChild(uid, cloudId);

  Future<void> pushSettings() async {
    final states = await _settings.sectionStates();
    await store.saveSettings(uid, {
      'daily_limit_min': await _settings.dailyLimitMinutes(),
      'sections_off': [
        for (final e in states.entries)
          if (!e.value) e.key
      ],
    });
  }

  Future<void> pushAll() async {
    for (final c in await _children.all()) {
      await pushChild(c.id);
    }
    await pushSettings();
  }

  /// يجلب بيانات الأسرة من السحابة ويدمجها محليًا. يعيد عدد الأطفال المدموجين.
  Future<int> pull() async {
    final docs = await store.loadChildren(uid);
    for (final d in docs) {
      if (d['cloud_id'] is String) await _snap.merge(d);
    }
    final s = await store.loadSettings(uid);
    if (s != null) {
      final limit = (s['daily_limit_min'] as num?)?.toInt();
      if (limit != null) await _settings.setDailyLimitMinutes(limit);
      final off = ((s['sections_off'] as List?) ?? const []).cast<String>();
      for (final id in SectionIds.all) {
        await _settings.setSectionEnabled(id, !off.contains(id));
      }
    }
    return docs.length;
  }

  void pushChildInBackground(int childId) => quietly(() => pushChild(childId));
  void pushSettingsInBackground() => quietly(pushSettings);
  void deleteChildInBackground(String cloudId) =>
      quietly(() => deleteChild(cloudId));

  /// يشغّل عملية مزامنة بلا انتظار ولا إيقاف للتطبيق عند الفشل.
  static void quietly(Future<void> Function() op) {
    unawaited(op().catchError((Object e) {
      debugPrint('sync failed (will retry later): $e');
    }));
  }
}
