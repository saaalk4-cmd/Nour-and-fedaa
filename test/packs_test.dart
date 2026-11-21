import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/packs/content_packs.dart';
import 'package:nourfadaa/data/db/app_database.dart';
import 'package:nourfadaa/data/repositories/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<int> _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) {
    final bytes = utf8.encode(c);
    a.addFile(ArchiveFile(n, bytes.length, bytes));
  });
  return ZipEncoder().encode(a);
}

class _FakeNet implements PackNet {
  _FakeNet(this.manifest, this.zips);

  String? manifest;
  final Map<String, List<int>> zips;
  final downloads = <String>[];
  bool failDownloads = false;

  @override
  Future<String?> getText(String url) async => manifest;

  @override
  Future<bool> download(String url, File to, void Function(int, int) onProgress) async {
    final name = url.split('/').last;
    downloads.add(name);
    if (failDownloads) return false;
    final z = zips[name]!;
    await to.writeAsBytes(z);
    onProgress(z.length, z.length);
    return true;
  }
}

void main() {
  final settings = SettingsRepository();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('nourfadaa_packs_');
    databaseFactoryFfi.setDatabasesPath(dir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.resetForTest();
    tmp = Directory.systemTemp.createTempSync('packs_');
  });

  String manifest({String voiceVer = 'v1', String quranVer = 'q1'}) => jsonEncode({
        'schema': 1,
        'packs': [
          {'name': 'voice', 'file': 'voice.zip', 'version': voiceVer, 'count': 1, 'bytes': 100},
          {'name': 'quran_30', 'file': 'quran_30.zip', 'version': quranVer, 'count': 1, 'bytes': 100},
        ],
      });

  _FakeNet net() => _FakeNet(manifest(), {
        'voice.zip': _zip({'index.json': '{"clips":["abc123"]}', 'abc123.mp3': 'audio'}),
        'quran_30.zip': _zip({'78_1.mp3': 'ayah'}),
      });

  PackStore store() => PackStore(settings, root: () async => tmp);

  PackDownloader downloader(PackStore s, PackNet n, {bool wifi = true}) =>
      PackDownloader(store: s, settings: settings, net: n, onWifi: () async => wifi, temp: () async => tmp);

  test('juz of each surah', () {
    expect([quranPackFor(58), quranPackFor(66), quranPackFor(67), quranPackFor(77), quranPackFor(78), quranPackFor(114)],
        ['quran_28', 'quran_28', 'quran_29', 'quran_29', 'quran_30', 'quran_30']);
    expect(quranPackFor(1), isNull);
    expect(quranPackFor(57), isNull);
  });

  test('downloads, unpacks and serves voice clips and ayat; then works offline and skips what is up to date', () async {
    final s = store();
    expect(await s.voicePath('abc123'), isNull);
    final n = net();
    final d = downloader(s, n);
    await d.run();
    expect(n.downloads, ['voice.zip', 'quran_30.zip']);
    expect(d.state.allReady, isTrue);
    expect(d.state.busy, isFalse);
    final v = await s.voicePath('abc123');
    expect(v, isNotNull);
    expect(await File(v!).readAsString(), 'audio');
    expect(await s.voicePath('nope'), isNull);
    expect(await File((await s.ayahPath(78, 1))!).readAsString(), 'ayah');
    expect(await s.ayahPath(78, 2), isNull);
    expect(await s.ayahPath(1, 1), isNull, reason: 'Fatiha stays inside the app');

    // نسخة جديدة من الأصوات فقط: تُنزَّل وحدها.
    n.downloads.clear();
    n.manifest = manifest(voiceVer: 'v2');
    await d.run();
    expect(n.downloads, ['voice.zip']);
    // بلا نت: ما نُزِّل يبقى شغالًا.
    n.manifest = null;
    await d.run();
    expect(await s.voicePath('abc123'), isNotNull);
    expect(d.state.message, contains('مفيش اتصال'));
  });

  test('respects the parent settings: wifi only, and automatic off', () async {
    final s = store();
    final n = net();
    expect(await settings.packWifiOnly(), isTrue);
    expect(await settings.packAuto(), isTrue);
    await downloader(s, n, wifi: false).run();
    expect(n.downloads, isEmpty);
    final manual = downloader(s, n, wifi: false);
    await manual.run(manual: true);
    expect(n.downloads, isEmpty);
    expect(manual.state.message, contains('الواي فاي'));
    await settings.setPackAuto(false);
    await downloader(s, n).run();
    expect(n.downloads, isEmpty, reason: 'automatic download is off');
    await downloader(s, n).run(manual: true);
    expect(n.downloads, isNotEmpty, reason: 'the button still works');
  });

  test('a broken download keeps nothing half-installed and tries again later', () async {
    final s = store();
    final n = net()..failDownloads = true;
    final d = downloader(s, n);
    await d.run();
    expect(d.state.busy, isFalse);
    expect(d.state.message, contains('هيكمّل'));
    expect(await s.installedVersion('voice'), isNull);
    expect(await s.voicePath('abc123'), isNull);
    n.failDownloads = false;
    await d.run();
    expect(await s.installedVersion('voice'), 'v1');
  });
}
