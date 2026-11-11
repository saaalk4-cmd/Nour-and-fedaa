# نُور وفداء 🌟

تطبيق Android عربي (RTL) لتعليم الأطفال المسلمين من 3 إلى 6 سنوات، يعمل بدون إنترنت.

- الإطار: Flutter + Riverpod + go_router + sqflite
- الخطة الهندسية: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## الحالة

المرحلة 1: الشاشة الرئيسية، ملفا الطفلتين (فداء ونور)، لوحة ولي الأمر برمز PIN، إظهار/إخفاء الأقسام.
بقية الأقسام تعرض «قريبًا إن شاء الله» وتُبنى في المراحل التالية.

## التشغيل محليًا

```bash
flutter create --org com --project-name nourfadaa --platforms android .   # مرة واحدة لتوليد مجلد android
flutter pub get
flutter run
```

## بناء APK

تلقائيًا: كل رفع إلى GitHub يشغّل `.github/workflows/build.yml`.
ثم من تبويب **Actions** ← آخر تشغيل ← **Artifacts** ← `nour-fedaa-apk`.

يدويًا: `flutter build apk --release` (و`flutter build appbundle` لملف AAB).

## قواعد المحتوى الديني

لا يُضاف أي حديث أو آية أو قول عالم دون مصدر موثوق محفوظ مع المحتوى. لا صور تجسّد الأنبياء أو الصحابة.
