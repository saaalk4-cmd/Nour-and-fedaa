import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'asset_clip_player.dart' show waitUntilFinished;
import 'voice_service.dart';

/// تسجيلات صوت الأهل على الجهاز: ملف لكل جملة باسم مفتاحها (VoiceService.clipKey).
/// تُستعمل بدل الصوت الآلي، وللأحاديث بدل أي نطق آلي. لا تغادر الجهاز إلا بنسخة احتياطية يختارها الأهل.
class UserVoiceStore implements UserVoice {
  UserVoiceStore._();

  static final UserVoiceStore instance = UserVoiceStore._();

  /// يتغير عند كل حفظ أو حذف أو استرجاع (لتحديث الشاشات).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Directory? _dir;
  Set<String>? _keys;
  AudioPlayer? _player;

  Future<Directory> _root() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/user_voice');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<Set<String>> keys() async {
    final k = _keys;
    if (k != null) return k;
    final dir = await _root();
    final out = <String>{};
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.m4a')) {
        final name = e.uri.pathSegments.last;
        if (await e.length() > 800) out.add(name.substring(0, name.length - 4));
      }
    }
    return _keys = out;
  }

  Future<String> pathFor(String key) async => '${(await _root()).path}/$key.m4a';

  /// مسار مؤقت للتسجيل الجاري (لا يصير نهائيًا إلا بـ[save]).
  Future<String> tempPath() async => '${(await getTemporaryDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

  @override
  Future<bool> has(String key) async => (await keys()).contains(key);

  @override
  Future<void> playAndWait(String key) async {
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    await p.play(DeviceFileSource(await pathFor(key)));
    await waitUntilFinished(p);
  }

  /// يشغّل ملفًا مؤقتًا (معاينة التسجيل قبل حفظه).
  Future<void> playFile(String path) async {
    final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await p.stop();
    await p.play(DeviceFileSource(path));
    await waitUntilFinished(p);
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> save(String key, String tempFile) async {
    final dest = File(await pathFor(key));
    await File(tempFile).copy(dest.path);
    try {
      await File(tempFile).delete();
    } catch (_) {}
    (await keys()).add(key);
    revision.value++;
  }

  Future<void> delete(String key) async {
    final f = File(await pathFor(key));
    if (await f.exists()) await f.delete();
    (await keys()).remove(key);
    revision.value++;
  }

  /// نسخة احتياطية: ملف zip فيه كل التسجيلات + manifest.json (يربط كل مفتاح بنص جملته).
  Future<File?> backup(Map<String, String> labels) async {
    final ks = (await keys()).toList()..sort();
    if (ks.isEmpty) return null;
    final archive = Archive();
    final manifest = <String, String>{};
    for (final k in ks) {
      final bytes = await File(await pathFor(k)).readAsBytes();
      archive.addFile(ArchiveFile.bytes('$k.m4a', bytes));
      if (labels[k] != null) manifest[k] = labels[k]!;
    }
    archive.addFile(ArchiveFile.string('manifest.json', jsonEncode({'app': 'nourfadaa', 'count': ks.length, 'phrases': manifest})));
    final out = ZipEncoder().encodeBytes(archive);
    final f = File('${(await getTemporaryDirectory()).path}/nour-fedaa-voice-backup.zip');
    await f.writeAsBytes(out, flush: true);
    return f;
  }

  /// يسترجع تسجيلات من نسخة احتياطية. يرجع عدد ما استُرجع (0 لو الملف غير صالح).
  Future<int> restore(List<int> zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      return 0;
    }
    final dir = await _root();
    var n = 0;
    for (final f in archive) {
      if (!f.isFile || !f.name.endsWith('.m4a')) continue;
      final name = f.name.split('/').last;
      // مفتاح صالح فقط (16 حرفًا سداسيًا) لحماية المجلد من أي اسم غريب.
      if (!RegExp(r'^[0-9a-f]{16}\.m4a$').hasMatch(name)) continue;
      await File('${dir.path}/$name').writeAsBytes(f.content, flush: true);
      n++;
    }
    _keys = null;
    revision.value++;
    return n;
  }
}
