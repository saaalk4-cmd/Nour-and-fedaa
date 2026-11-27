import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/repositories/badge_repository.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/placement_repository.dart';
import 'package:buraq/data/repositories/progress_repository.dart';
import 'package:buraq/data/repositories/review_repository.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/data/sync/cloud_store.dart';
import 'package:buraq/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// جهاز جديد = قاعدة محلية فارغة جديدة.
Future<void> _freshDevice() async {
  await AppDatabase.instance.close();
  await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('buraq_test').path);
}

Future<int> _addChild(String name) => ChildRepository().add(ChildDraft(
    nickname: name, avatar: 'star', birthYear: 2019, birthMonth: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(_freshDevice);

  test('every new child gets a stable cloud id', () async {
    final a = await ChildRepository().byId(await _addChild('أ'));
    final b = await ChildRepository().byId(await _addChild('ب'));
    expect(a!.cloudId, hasLength(32));
    expect(a.cloudId, isNot(b!.cloudId));
  });

  test('a family moves to a new device with progress, levels, badges, reviews and settings',
      () async {
    final store = MemoryCloudStore();
    final id = await _addChild('نجمة');
    await ProgressRepository().complete(childId: id, lessonId: 'l1', stars: 3);
    await PlacementRepository().save(id, {'quran': 2, 'arabic': 3});
    await BadgeRepository().evaluate(id);
    await SettingsRepository().setDailyLimitMinutes(45);
    await SettingsRepository().setSectionEnabled('arabic', false);
    final cloudId = (await ChildRepository().byId(id))!.cloudId;

    await SyncService(uid: 'u1', store: store).pushAll();
    expect(store.children['u1']!.keys, [cloudId]);

    await _freshDevice();
    expect(await ChildRepository().all(), isEmpty);
    expect(await SyncService(uid: 'u1', store: store).pull(), 1);

    final restored = (await ChildRepository().all()).single;
    expect(restored.nickname, 'نجمة');
    expect(restored.cloudId, cloudId);
    expect(restored.stars, 3);
    expect(await ProgressRepository().isDone(restored.id, 'l1'), isTrue);
    expect(await PlacementRepository().levels(restored.id),
        {'quran': 2, 'arabic': 3});
    expect(await BadgeRepository().earned(restored.id), ['first_lesson']);
    expect(await ReviewRepository().due(restored.id, now: DateTime(2100)), ['l1']);
    expect(await SettingsRepository().dailyLimitMinutes(), 45);
    expect(await SettingsRepository().isSectionEnabled('arabic'), isFalse);
  });

  test('pulling twice does not duplicate children', () async {
    final store = MemoryCloudStore();
    await _addChild('أ');
    final sync = SyncService(uid: 'u1', store: store);
    await sync.pushAll();
    await sync.pull();
    await sync.pull();
    expect((await ChildRepository().all()).length, 1);
  });

  test('merge keeps local work and takes the higher stars', () async {
    final store = MemoryCloudStore();
    final id = await _addChild('أ');
    final sync = SyncService(uid: 'u1', store: store);
    await ProgressRepository().complete(childId: id, lessonId: 'cloud', stars: 5);
    await sync.pushChild(id); // السحابة: ٥ نجوم ودرس cloud

    // محليًا بعد ذلك على جهاز آخر لنفس الطفل: درس آخر بنجمتين فقط
    final cloudDoc = store.children['u1']!.values.single;
    await _freshDevice();
    final localId = await ChildRepository().add(const ChildDraft(
        nickname: 'أ', avatar: 'star', birthYear: 2019, birthMonth: 3));
    final db = await AppDatabase.instance.database;
    await db.update('children', {'cloud_id': cloudDoc['cloud_id']},
        where: 'id = ?', whereArgs: [localId]);
    await ProgressRepository().complete(childId: localId, lessonId: 'local', stars: 2);

    await sync.pull();
    final c = (await ChildRepository().all()).single;
    expect(c.stars, 5); // الأكبر
    expect(await ProgressRepository().isDone(c.id, 'local'), isTrue);
    expect(await ProgressRepository().isDone(c.id, 'cloud'), isTrue);
  });

  test('deleting a child removes its cloud copy', () async {
    final store = MemoryCloudStore();
    final id = await _addChild('أ');
    final sync = SyncService(uid: 'u1', store: store);
    await sync.pushChild(id);
    final cloudId = (await ChildRepository().byId(id))!.cloudId!;
    await sync.deleteChild(cloudId);
    expect(store.children['u1'], isEmpty);
  });

  test('each parent only sees their own data in the store', () async {
    final store = MemoryCloudStore();
    final id = await _addChild('أ');
    await SyncService(uid: 'parentA', store: store).pushChild(id);
    await _freshDevice();
    expect(await SyncService(uid: 'parentB', store: store).pull(), 0);
    expect(await ChildRepository().all(), isEmpty);
  });
}
