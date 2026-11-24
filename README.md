# براق

تطبيق عربي (RTL) لتعليم المسلمين من سنتين إلى 14 سنة: قرآن وصلاة وعقيدة وعربية وأخلاق، بمسار متدرّج لكل فئة عمرية. يعتمد على الإنترنت (Firebase) لحجم تطبيق صغير ومحتوى قابل للتحديث.

- الإطار: Flutter + Riverpod + go_router
- الخطة: [docs/PLAN.md](docs/PLAN.md)
- الهندسة: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- منهج البراعم (2–4): [docs/curriculum/buraem-2-4.md](docs/curriculum/buraem-2-4.md)
- الهوية والتصميم: [docs/brand/](docs/brand/)
- إعداد Firebase: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

## الحالة

**المرحلة 0 (قيد التنفيذ):** إعادة التسمية إلى «براق»، ألوان الهوية، أيقونة التطبيق، وتجهيز Firebase.
الشاشات الحالية (الرئيسية، ملفات الأطفال، لوحة ولي الأمر) من مرحلة تجريبية سابقة وستُستبدل في المرحلة 1 برحلة التسجيل والفئات العمرية الأربع.

## التشغيل محليًا

```bash
flutter create --org com.buraq --project-name buraq --platforms android .   # مرة واحدة لتوليد مجلد android
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## بناء APK

تلقائيًا: كل رفع إلى GitHub يشغّل `.github/workflows/build.yml`، ثم **Actions** ← آخر تشغيل ← **Artifacts** ← `buraq-apk`.

يدويًا: `flutter build apk --release` (و`flutter build appbundle` لملف AAB على Google Play).

## قواعد المحتوى الديني

لا يُضاف أي حديث أو آية أو قول عالم دون مصدر موثوق محفوظ مع المحتوى. نص القرآن يُستورد من مصدر مرخّص ولا يُكتب يدويًا. لا صور تجسّد الأنبياء أو الصحابة.
