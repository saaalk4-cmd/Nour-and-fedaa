import 'package:buraq/data/models/parent_account.dart';
import 'package:buraq/data/providers.dart';
import 'package:buraq/data/repositories/account_repository.dart';
import 'package:buraq/features/onboarding/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAccounts implements AccountRepository {
  _FakeAccounts({this.failWith});
  final String? failWith;
  final calls = <String>[];

  @override
  bool get isReal => true;
  @override
  Future<ParentAccount?> current() async => null;
  @override
  Future<ParentAccount> signUpWithEmail(String e, String p) async {
    calls.add('up:$e');
    if (failWith != null) throw AccountException(authErrorMessage(failWith!));
    return ParentAccount(method: SignInMethod.email, email: e, uid: 'u1');
  }

  @override
  Future<ParentAccount> signInWithEmail(String e, String p) async {
    calls.add('in:$e');
    if (failWith != null) throw AccountException(authErrorMessage(failWith!));
    return ParentAccount(method: SignInMethod.email, email: e, uid: 'u1');
  }

  @override
  Future<void> sendPasswordReset(String e) async => calls.add('reset:$e');
  @override
  Future<void> signOut() async {}
  @override
  Future<void> confirmPassword(String p) async {}
  @override
  Future<void> deleteAccount() async {}
}

Future<void> _show(WidgetTester t, _FakeAccounts repo) async {
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const AccountScreen()),
    GoRoute(path: '/onboarding/pin', builder: (_, __) => const Text('PIN')),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [accountRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await t.pumpAndSettle();
}

void main() {
  test('auth error codes map to Arabic messages', () {
    expect(authErrorMessage('email-already-in-use'), contains('مسجّل'));
    expect(authErrorMessage('invalid-credential'), 'البريد أو كلمة المرور غير صحيحة');
    expect(authErrorMessage('something-new'), 'تعذّر إتمام العملية، حاول مرة أخرى');
  });

  testWidgets('validates input before calling the server', (t) async {
    final repo = _FakeAccounts();
    await _show(t, repo);
    await t.enterText(find.byKey(const Key('email_field')), 'bad');
    await t.enterText(find.byKey(const Key('password_field')), '123456');
    await t.tap(find.text('إنشاء الحساب'));
    await t.pump();
    expect(find.text('البريد الإلكتروني غير صحيح'), findsOneWidget);
    await t.enterText(find.byKey(const Key('email_field')), 'a@b.co');
    await t.enterText(find.byKey(const Key('password_field')), '123');
    await t.tap(find.text('إنشاء الحساب'));
    await t.pump();
    expect(find.text('كلمة المرور ٦ أحرف على الأقل'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('sign up success moves to PIN setup; no local-mode notice', (t) async {
    final repo = _FakeAccounts();
    await _show(t, repo);
    expect(find.text(kLocalAccountNotice), findsNothing);
    await t.enterText(find.byKey(const Key('email_field')), 'a@b.co');
    await t.enterText(find.byKey(const Key('password_field')), '123456');
    await t.tap(find.text('إنشاء الحساب'));
    await t.pumpAndSettle();
    expect(repo.calls, ['up:a@b.co']);
    expect(find.text('PIN'), findsOneWidget);
  });

  testWidgets('server error is shown in Arabic and stays on the screen', (t) async {
    final repo = _FakeAccounts(failWith: 'invalid-credential');
    await _show(t, repo);
    await t.tap(find.text('لدي حساب'));
    await t.pump();
    await t.enterText(find.byKey(const Key('email_field')), 'a@b.co');
    await t.enterText(find.byKey(const Key('password_field')), '123456');
    await t.tap(find.text('الدخول'));
    await t.pumpAndSettle();
    expect(repo.calls, ['in:a@b.co']);
    expect(find.text('البريد أو كلمة المرور غير صحيحة'), findsOneWidget);
    expect(find.text('PIN'), findsNothing);
  });

  testWidgets('forgot password sends a reset email', (t) async {
    final repo = _FakeAccounts();
    await _show(t, repo);
    await t.tap(find.text('لدي حساب'));
    await t.pump();
    await t.enterText(find.byKey(const Key('email_field')), 'a@b.co');
    await t.tap(find.text('نسيت كلمة المرور'));
    await t.pumpAndSettle();
    expect(repo.calls, ['reset:a@b.co']);
  });
}
