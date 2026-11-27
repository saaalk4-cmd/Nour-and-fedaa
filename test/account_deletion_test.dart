import 'dart:io';

import 'package:buraq/data/account_deletion.dart';
import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/models/child.dart';
import 'package:buraq/data/models/parent_account.dart';
import 'package:buraq/data/repositories/account_repository.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:buraq/data/repositories/settings_repository.dart';
import 'package:buraq/data/sync/cloud_store.dart';
import 'package:buraq/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Accounts implements AccountRepository {
  _Accounts({this.passwordOk = true});
  final bool passwordOk;
  bool deleted = false;

  @override
  bool get isReal => true;
  @override
  Future<ParentAccount?> current() async => deleted
      ? null
      : const ParentAccount(method: SignInMethod.email, email: 'a@b.co', uid: 'u1');
  @override
  Future<void> confirmPassword(String p) async {
    if (!passwordOk) throw const AccountException('البريد أو كلمة المرور غير صحيحة');
  }

  @override
  Future<void> deleteAccount() async => deleted = true;
  @override
  Future<ParentAccount> signInWithEmail(String e, String p) => throw UnimplementedError();
  @override
  Future<ParentAccount> signUpWithEmail(String e, String p) => throw UnimplementedError();
  @override
  Future<void> sendPasswordReset(String e) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    await AppDatabase.instance.close();
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('buraq_test').path);
  });

  Future<MemoryCloudStore> seeded() async {
    final store = MemoryCloudStore();
    await ChildRepository().add(const ChildDraft(
        nickname: 'أ', avatar: 'star', birthYear: 2019, birthMonth: 1));
    await SettingsRepository().setPin('1234');
    await SyncService(uid: 'u1', store: store).pushAll();
    return store;
  }

  test('deleting the account removes cloud data, the login and local data', () async {
    final store = await seeded();
    final accounts = _Accounts();
    await deleteFamilyAccount(accounts: accounts, store: store, password: 'x');
    expect(store.children['u1'], isNull);
    expect(store.settings['u1'], isNull);
    expect(accounts.deleted, isTrue);
    expect(await ChildRepository().all(), isEmpty);
    expect(await SettingsRepository().hasPin(), isFalse);
  });

  test('wrong password stops everything and deletes nothing', () async {
    final store = await seeded();
    final accounts = _Accounts(passwordOk: false);
    await expectLater(
        deleteFamilyAccount(accounts: accounts, store: store, password: 'bad'),
        throwsA(isA<AccountException>()));
    expect(store.children['u1'], isNotEmpty);
    expect(accounts.deleted, isFalse);
    expect(await ChildRepository().all(), hasLength(1));
  });
}
