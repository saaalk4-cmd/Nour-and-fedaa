import '../models/parent_account.dart';
import 'settings_repository.dart';

/// واجهة حساب ولي الأمر. التنفيذ الحالي محلي، ويُستبدل بـFirebase Auth لاحقًا
/// دون تغيير باقي التطبيق.
abstract class AccountRepository {
  Future<ParentAccount?> current();
  Future<ParentAccount> signIn(SignInMethod method, {String? email});
  Future<void> signOut();
}

/// تنفيذ محلي مؤقت: يحفظ طريقة الدخول والبريد في إعدادات الجهاز.
/// لا يتحقق من هوية أحد، ولا يُستخدم في الإنتاج.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this._settings);

  final SettingsRepository _settings;

  static const _kMethod = 'account_method';
  static const _kEmail = 'account_email';

  @override
  Future<ParentAccount?> current() async {
    final m = await _settings.read(_kMethod);
    if (m == null) return null;
    final method = SignInMethod.values.firstWhere(
      (e) => e.name == m,
      orElse: () => SignInMethod.email,
    );
    return ParentAccount(method: method, email: await _settings.read(_kEmail));
  }

  @override
  Future<ParentAccount> signIn(SignInMethod method, {String? email}) async {
    await _settings.write(_kMethod, method.name);
    if (email != null) await _settings.write(_kEmail, email);
    return ParentAccount(method: method, email: email);
  }

  @override
  Future<void> signOut() async {
    await _settings.remove(_kMethod);
    await _settings.remove(_kEmail);
  }
}
