import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
      firebaseReady = true;
    } catch (e) {
      // التطبيق يعمل بالوضع المحلي إن تعذّرت التهيئة.
      debugPrint('Firebase init failed: $e');
    }
  }
  runApp(ProviderScope(
    overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
    child: const BuraqApp(),
  ));
}
