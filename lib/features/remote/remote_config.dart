/// إعداد خدمة «المتابعة من تليفون الأهل» (Firebase Firestore عبر REST، بلا مكتبات إضافية).
///
/// القيمتان من مشروع Firebase الخاص بالأسرة (Project settings ← General):
/// - Project ID
/// - Web API Key
/// خطوات الإعداد وقواعد الأمان في docs/REMOTE_SETUP.md و firestore.rules.
/// مفتاح الويب في Firebase ليس سرًا (يحدد المشروع فقط)؛ الحماية بقواعد Firestore وبكود الأسرة.
class RemoteConfig {
  const RemoteConfig._();

  static const projectId = '';
  static const apiKey = '';

  static bool get ready => projectId.isNotEmpty && apiKey.isNotEmpty;
}
