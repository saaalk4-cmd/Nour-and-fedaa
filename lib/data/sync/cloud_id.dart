import 'dart:math';

/// معرّف عشوائي ثابت (٣٢ حرفًا ست عشريًا) لربط الطفل بنسخته السحابية.
String newCloudId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
}
