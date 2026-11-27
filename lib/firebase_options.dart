// إعدادات Firebase لتطبيق Android (مشروع buraq-b5791).
// مفتاح Firebase هنا ليس سرًا بحد ذاته (يُضمَّن في كل تطبيق منشور)، والحماية
// بقواعد الأمان وApp Check وتقييد المفتاح على حزمة التطبيق في Google Cloud.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAG_8zIPqpNCT_O9JteUe4RPbxWtUvVpU0',
    appId: '1:941232989537:android:fa92edeafcb1ce690c1120',
    messagingSenderId: '941232989537',
    projectId: 'buraq-b5791',
    storageBucket: 'buraq-b5791.firebasestorage.app',
  );
}
