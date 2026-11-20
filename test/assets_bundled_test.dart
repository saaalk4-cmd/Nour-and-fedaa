import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/features/song/song_screen.dart';

/// Flutter لا يضم الفولدرات الفرعية تلقائيًا: كل فولدر فيه ملفات لازم يُكتب في pubspec.yaml،
/// وإلا الملف يختفي من التطبيق بصمت (زي ما حصل مع الأغنية أول مرة).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every folder under assets/ that has files is listed in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final listed = RegExp(r'^\s*-\s*(assets/\S*)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m.group(1)!.endsWith('/') ? m.group(1)! : '${m.group(1)!}/')
        .toSet();
    final missing = <String>[];
    for (final d in [Directory('assets'), ...Directory('assets').listSync(recursive: true).whereType<Directory>()]) {
      final hasFiles = d.listSync().whereType<File>().any((f) => !f.path.split('/').last.startsWith('.'));
      final path = '${d.path.replaceAll('\\', '/')}/';
      // assets/icon: مصدر أيقونة الموبايل (flutter_launcher_icons)، مش محتاجة جوه التطبيق.
      if (hasFiles && path != 'assets/' && path != 'assets/icon/' && !listed.contains(path)) missing.add(path);
    }
    expect(missing, isEmpty, reason: 'add these to flutter.assets in pubspec.yaml');
  });

  test('the song is really inside the app bundle', () async {
    final data = await rootBundle.load('assets/$kSongAsset');
    expect(data.lengthInBytes, greaterThan(1000000));
  });
}
