import 'db/app_database.dart';
import 'repositories/account_repository.dart';
import 'sync/cloud_store.dart';

/// حذف الحساب كاملًا (شرط Google Play للتطبيقات التي تنشئ حسابات):
/// ١) التحقق من كلمة المرور، ٢) حذف بيانات الأسرة من السحابة،
/// ٣) حذف حساب الدخول، ٤) مسح بيانات هذا الجهاز.
/// يتوقف عند أول خطأ دون أن يمسح ما بعده.
Future<void> deleteFamilyAccount({
  required AccountRepository accounts,
  required CloudStore? store,
  required String password,
  AppDatabase? db,
}) async {
  await accounts.confirmPassword(password);
  final acc = await accounts.current();
  final uid = acc?.uid;
  if (store != null && uid != null) {
    try {
      await store.deleteAll(uid);
    } catch (_) {
      throw const AccountException(
          'تعذّر حذف البيانات من السحابة، تأكد من الاتصال وأعد المحاولة');
    }
  }
  await accounts.deleteAccount();
  await (db ?? AppDatabase.instance).wipe();
}
