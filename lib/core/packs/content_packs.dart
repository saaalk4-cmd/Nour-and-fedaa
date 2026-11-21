import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/settings_repository.dart';

/// مكان حزم التنزيل (يرفعها CI بـ tools/build_packs.py): manifest.json + voice.zip + quran_28/29/30.zip.
const kPacksBase = 'https://github.com/saaalk4-cmd/Nour-and-fedaa/releases/download/content-packs';

/// حزمة واحدة في manifest.json.
class PackEntry {
  const PackEntry({required this.name, required this.file, required this.version, required this.count, required this.bytes});

  final String name;
  final String file;
  final String version;
  final int count;
  final int bytes;

  factory PackEntry.fromJson(Map<String, dynamic> j) => PackEntry(
        name: j['name'] as String,
        file: j['file'] as String,
        version: j['version'] as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      );

  static List<PackEntry> parseManifest(String raw) => [
        for (final p in ((jsonDecode(raw) as Map<String, dynamic>)['packs'] as List<dynamic>? ?? const []))
          PackEntry.fromJson(p as Map<String, dynamic>),
      ];
}

/// اسم حزمة التلاوة لآية (أجزاء 28–30)، أو null.
String? quranPackFor(int surah) {
  if (surah >= 58 && surah <= 66) return 'quran_28';
  if (surah >= 67 && surah <= 77) return 'quran_29';
  if (surah >= 78 && surah <= 114) return 'quran_30';
  return null;
}

/// الحزم المحفوظة على الجهاز: مجلد لكل حزمة داخل مجلد التطبيق، ونسختها في الإعدادات.
class PackStore {
  PackStore(this._settings, {Future<Directory> Function()? root}) : _root = root ?? getApplicationSupportDirectory;

  final SettingsRepository _settings;
  final Future<Directory> Function() _root;

  Future<Directory> packsDir() async => Directory('${(await _root()).path}/packs');

  Future<Directory> dirOf(String name) async => Directory('${(await packsDir()).path}/$name');

  Future<String?> installedVersion(String name) => _settings.getValue('pack_ver_$name');

  Future<void> _setInstalled(String name, String version) => _settings.setValue('pack_ver_$name', version);

  Set<String>? _voiceKeys;

  /// يُستدعى بعد تثبيت حزمة جديدة.
  void invalidate() => _voiceKeys = null;

  Future<Set<String>> _loadVoiceKeys() async {
    try {
      final f = File('${(await dirOf('voice')).path}/index.json');
      if (!await f.exists()) return <String>{};
      final list = (jsonDecode(await f.readAsString()) as Map<String, dynamic>)['clips'] as List<dynamic>;
      return {for (final k in list) k as String};
    } catch (_) {
      return <String>{};
    }
  }

  /// ملف مقطع صوت من حزمة الأصوات (أو null لو غير منزَّل).
  Future<String?> voicePath(String key) async {
    final keys = _voiceKeys ??= await _loadVoiceKeys();
    if (!keys.contains(key)) return null;
    return '${(await dirOf('voice')).path}/$key.mp3';
  }

  /// ملف تلاوة آية من حزم الأجزاء (أو null).
  Future<String?> ayahPath(int surah, int ayah) async {
    final name = quranPackFor(surah);
    if (name == null) return null;
    try {
      final f = File('${(await dirOf(name)).path}/${surah}_$ayah.mp3');
      return await f.exists() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  /// يفك ملف zip منزَّل إلى مجلد الحزمة (يستبدل القديم كاملًا) ويسجّل النسخة.
  Future<void> install(String name, String version, File zip) async {
    final dest = await dirOf(name);
    final tmp = Directory('${dest.path}.new');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    await extractFileToDisk(zip.path, tmp.path);
    if (await dest.exists()) await dest.delete(recursive: true);
    await tmp.rename(dest.path);
    await _setInstalled(name, version);
    invalidate();
  }
}

/// حالة التنزيل (لوحة الأهل).
class PackStatus {
  const PackStatus({
    this.busy = false,
    this.current,
    this.received = 0,
    this.total = 0,
    this.message,
    this.available = const [],
    this.installed = const {},
  });

  final bool busy;
  final String? current;
  final int received;
  final int total;
  final String? message;
  final List<PackEntry> available;
  final Map<String, String?> installed;

  double get progress => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);

  bool upToDate(PackEntry p) => installed[p.name] == p.version;

  bool get allReady => available.isNotEmpty && available.every(upToDate);

  PackStatus copyWith({
    bool? busy,
    String? current,
    int? received,
    int? total,
    String? message,
    List<PackEntry>? available,
    Map<String, String?>? installed,
    bool clearCurrent = false,
  }) =>
      PackStatus(
        busy: busy ?? this.busy,
        current: clearCurrent ? null : (current ?? this.current),
        received: received ?? this.received,
        total: total ?? this.total,
        message: message,
        available: available ?? this.available,
        installed: installed ?? this.installed,
      );
}

/// الشبكة (تُستبدل في الاختبارات).
abstract class PackNet {
  Future<String?> getText(String url);

  /// ينزّل إلى ملف ويبلّغ بالتقدم. يرجع false عند أي فشل.
  Future<bool> download(String url, File to, void Function(int received, int total) onProgress);
}

class HttpPackNet implements PackNet {
  @override
  Future<String?> getText(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final res = await (await c.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  @override
  Future<bool> download(String url, File to, void Function(int, int) onProgress) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final res = await (await c.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) return false;
      final total = res.contentLength;
      var got = 0;
      sink = to.openWrite();
      await for (final chunk in res.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(got, total);
      }
      await sink.close();
      sink = null;
      return total <= 0 || got == total;
    } catch (_) {
      return false;
    } finally {
      await sink?.close();
      c.close(force: true);
    }
  }
}

/// ينزّل الحزم الناقصة أو القديمة، بهدوء. لا يرمي أبدًا.
class PackDownloader extends StateNotifier<PackStatus> {
  PackDownloader({
    required PackStore store,
    required SettingsRepository settings,
    PackNet? net,
    Future<bool> Function()? onWifi,
    Future<Directory> Function()? temp,
  })  : _store = store,
        _settings = settings,
        _net = net ?? HttpPackNet(),
        _onWifi = onWifi ?? (() async => true),
        _temp = temp ?? getTemporaryDirectory,
        super(const PackStatus());

  final PackStore _store;
  final SettingsRepository _settings;
  final PackNet _net;
  final Future<bool> Function() _onWifi;
  final Future<Directory> Function() _temp;

  Future<Map<String, String?>> _installed(List<PackEntry> packs) async =>
      {for (final p in packs) p.name: await _store.installedVersion(p.name)};

  /// [manual]: زر «نزّلي دلوقتي» (يتجاهل «تلقائي» لكن يحترم «واي فاي فقط»).
  Future<void> run({bool manual = false}) async {
    if (state.busy) return;
    try {
      if (!manual && !await _settings.packAuto()) return;
      if (await _settings.packWifiOnly() && !await _onWifi()) {
        if (manual) state = state.copyWith(message: 'شغّلي الواي فاي، أو اقفلي «على الواي فاي بس»');
        return;
      }
      state = state.copyWith(busy: true, message: 'بيدوّر على الجديد…');
      final raw = await _net.getText('$kPacksBase/manifest.json');
      if (raw == null) {
        state = state.copyWith(busy: false, message: 'مفيش اتصال دلوقتي، هيحاول تاني بعدين');
        return;
      }
      final packs = PackEntry.parseManifest(raw);
      var installed = await _installed(packs);
      state = state.copyWith(available: packs, installed: installed);
      final dir = await _temp();
      for (final p in packs) {
        if (installed[p.name] == p.version) continue;
        state = state.copyWith(current: p.name, received: 0, total: p.bytes, message: null);
        final zip = File('${dir.path}/${p.file}');
        final ok = await _net.download('$kPacksBase/${p.file}', zip, (got, total) {
          state = state.copyWith(received: got, total: total > 0 ? total : p.bytes);
        });
        if (!ok) {
          state = state.copyWith(busy: false, clearCurrent: true, message: 'التنزيل وقف، هيكمّل المرة الجاية');
          if (await zip.exists()) await zip.delete();
          return;
        }
        await _store.install(p.name, p.version, zip);
        if (await zip.exists()) await zip.delete();
        installed = await _installed(packs);
        state = state.copyWith(installed: installed);
      }
      state = state.copyWith(busy: false, clearCurrent: true, message: 'كل حاجة متنزّلة ✅');
    } catch (_) {
      state = state.copyWith(busy: false, clearCurrent: true, message: 'التنزيل وقف، هيكمّل المرة الجاية');
    }
  }

  /// يقرأ ما هو مثبّت (لعرضه قبل أي تنزيل).
  Future<void> refreshInstalled() async {
    if (state.available.isEmpty) return;
    state = state.copyWith(installed: await _installed(state.available));
  }
}
