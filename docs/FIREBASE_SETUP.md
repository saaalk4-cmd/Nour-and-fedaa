# إعداد Firebase

## الحالة (٢٧ نوفمبر ٢٠٢٦)
- ✅ المشروع: `buraq-b5791`، تطبيق Android بالحزمة `com.buraq.buraq`.
- ✅ التطبيق يتهيأ بإعدادات `lib/firebase_options.dart` (بلا ملف `google-services.json` في المستودع، فهو في `.gitignore`).
- ✅ حساب ولي الأمر بالبريد وكلمة المرور عبر Firebase Auth.
- ⏳ **مطلوب من صاحب المشروع في Firebase Console:**
  1. Authentication > Sign-in method: فعّل **Email/Password**.
  2. Firestore Database: أنشئ قاعدة (Production mode، أقرب منطقة مثل `europe-west`)، ثم الصق محتوى `firestore.rules` في تبويب Rules وانشر.
  3. Storage: فعّله، ثم الصق `storage.rules` وانشر.
  4. Google Cloud Console > APIs & Services > Credentials: قيّد مفتاح Android على الحزمة `com.buraq.buraq` (وأضف SHA-1 عند توفر مفتاح التوقيع).
- ⏳ الدخول بجوجل: يحتاج مفتاح توقيع ثابتًا (البناء الحالي على GitHub يولّد مفتاحًا جديدًا كل مرة) ثم إضافة SHA-1 في إعدادات التطبيق.
- ✅ Firestore منشأ وقواعده منشورة، والمزامنة مفعّلة في الكود.
  - البنية: `parents/{uid}` (الحد اليومي والأقسام الموقوفة) و`parents/{uid}/children/{cloudId}` (ملف الطفل وتقدّمه ومستواه وشاراته ومراجعاته).
  - رمز PIN ووقت الاستخدام اليومي يبقيان على الجهاز فقط.
- ⏳ App Check وRemote Config: خطوات لاحقة.

---

# إعداد Firebase لتطبيق براق

هذه خطوات تحتاج حسابك على Google (لا يمكن تنفيذها آليًا). بعد إتمامها أكمل ربط الكود.

## 1) قرارات تسبق الإنشاء
- **معرّف الحزمة (applicationId):** المقترح `com.buraq.buraq` (من `--org com.buraq --project-name buraq`). **لا يتغيّر بعد النشر على Google Play**؛ إن أردت غيره (مثل `app.buraq.learn`) فقرّره قبل البدء.
- **منطقة قاعدة البيانات:** اختر الأقرب لجمهورك (مثلًا `europe-west` أو `me-central`).

## 2) إنشاء المشروع
1. console.firebase.google.com ← Add project ← الاسم «Buraq».
2. عطّل Google Analytics الآن (لتفادي جمع بيانات عن الأطفال). فعّله لاحقًا بقرار واعٍ ومتوافق مع سياسة Families.
3. Add app ← Android ← أدخل معرّف الحزمة، ثم نزّل `google-services.json`.

## 3) الخدمات المطلوبة
- **Authentication:** فعّل Google وEmail/Password (لحسابات أولياء الأمور فقط).
- **Firestore:** أنشئها في وضع الإنتاج (Production mode) مع القواعد أدناه.
- **Storage:** للصوتيات والصور.
- **Remote Config:** لتفعيل/إيقاف الأقسام.
- **App Check:** فعّله (Play Integrity) قبل الإطلاق.

## 4) قواعد Firestore المقترحة (نقطة بداية)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    // حساب ولي الأمر وبياناته فقط
    match /parents/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    // المحتوى التعليمي: قراءة لأي مسجّل، لا كتابة من التطبيق
    match /content/{document=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

## 5) ما أحتاجه منك للمتابعة
1. ملف `google-services.json` (ضعه في `android/app/` ولا ترفعه علنًا إن كان المستودع عامًا؛ ليس سرًّا لكنه يحدد مشروعك).
2. قرارك في معرّف الحزمة.
3. بصمة SHA-1 لمفتاح التوقيع (لتسجيل الدخول بجوجل): `keytool -list -v -keystore <keystore>`.

## 6) خصوصية الأطفال
- بيانات الطفل: لقب وشهر/سنة ميلاد وتقدّم فقط، تحت حساب ولي الأمر.
- لا معرّفات إعلانية، لا موقع دقيق، لا إعلانات.
- سياسة خصوصية بالعربية قبل أي اختبار عام.
