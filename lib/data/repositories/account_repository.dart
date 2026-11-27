import 'package:firebase_auth/firebase_auth.dart';

import '../models/parent_account.dart';
import 'settings_repository.dart';

/// خطأ حساب برسالة عربية جاهزة للعرض.
class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// واجهة حساب ولي الأمر.
abstract class AccountRepository {
  /// هل هذا حساب حقيقي (Firebase) أم وضع تجريبي محلي؟
  bool get isReal;

  Future<ParentAccount?> current();
  Future<ParentAccount> signUpWithEmail(String email, String password);
  Future<ParentAccount> signInWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

/// حساب حقيقي عبر Firebase Auth (بريد وكلمة مرور).
class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  bool get isReal => true;

  ParentAccount _map(User u) =>
      ParentAccount(method: SignInMethod.email, email: u.email, uid: u.uid);

  @override
  Future<ParentAccount?> current() async {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Future<ParentAccount> signUpWithEmail(String email, String password) =>
      _guard(() async {
        final c = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        return _map(c.user!);
      });

  @override
  Future<ParentAccount> signInWithEmail(String email, String password) =>
      _guard(() async {
        final c = await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        return _map(c.user!);
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseAuthException catch (e) {
      throw AccountException(authErrorMessage(e.code));
    }
  }
}

/// رسائل عربية لأخطاء Firebase Auth الشائعة.
String authErrorMessage(String code) => switch (code) {
      'invalid-email' => 'البريد الإلكتروني غير صحيح',
      'email-already-in-use' => 'هذا البريد مسجّل بالفعل، اختر «لدي حساب»',
      'weak-password' => 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'البريد أو كلمة المرور غير صحيحة',
      'user-disabled' => 'هذا الحساب موقوف',
      'too-many-requests' => 'محاولات كثيرة، حاول بعد قليل',
      'network-request-failed' => 'لا يوجد اتصال بالإنترنت',
      'operation-not-allowed' => 'الدخول بالبريد غير مفعّل في المشروع بعد',
      _ => 'تعذّر إتمام العملية، حاول مرة أخرى',
    };

/// وضع تجريبي محلي (حين لا يتوفر Firebase، مثل الاختبارات). لا يتحقق من أحد.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this._settings);

  final SettingsRepository _settings;

  static const _kMethod = 'account_method';
  static const _kEmail = 'account_email';

  @override
  bool get isReal => false;

  @override
  Future<ParentAccount?> current() async {
    final m = await _settings.read(_kMethod);
    if (m == null) return null;
    return ParentAccount(
        method: SignInMethod.email, email: await _settings.read(_kEmail));
  }

  Future<ParentAccount> _save(String email) async {
    await _settings.write(_kMethod, SignInMethod.email.name);
    await _settings.write(_kEmail, email);
    return ParentAccount(method: SignInMethod.email, email: email);
  }

  @override
  Future<ParentAccount> signUpWithEmail(String email, String password) =>
      _save(email);

  @override
  Future<ParentAccount> signInWithEmail(String email, String password) =>
      _save(email);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    await _settings.remove(_kMethod);
    await _settings.remove(_kEmail);
  }
}
