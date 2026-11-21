import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'remote_config.dart';

/// ما يُرفع ويُقرأ: ملخص الأسرة نصًّا (JSON) ووقت آخر تحديث.
class RemoteDoc {
  const RemoteDoc({required this.json, required this.updatedAt});

  final String json;
  final DateTime updatedAt;
}

/// الاتصال بالخدمة (يُستبدل في الاختبارات).
abstract class RemoteClient {
  /// يكتب ملخص الأسرة. يرجع true عند النجاح.
  Future<bool> put(String code, String json);

  /// يقرأ ملخص الأسرة، أو null لو لا يوجد بعد. يرمي عند انقطاع النت.
  Future<RemoteDoc?> get(String code);
}

/// Firestore REST: families/{code} = { json, updatedAt, v }.
class FirestoreRemoteClient implements RemoteClient {
  FirestoreRemoteClient({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  Uri _uri(String code, {bool write = false}) {
    final base = 'https://firestore.googleapis.com/v1/projects/${RemoteConfig.projectId}'
        '/databases/(default)/documents/families/$code';
    final q = <String, dynamic>{'key': RemoteConfig.apiKey};
    if (write) q['updateMask.fieldPaths'] = ['json', 'updatedAt', 'v'];
    return Uri.parse(base).replace(queryParameters: q);
  }

  @override
  Future<bool> put(String code, String json) async {
    if (!RemoteConfig.ready) return false;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.patchUrl(_uri(code, write: true)).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'fields': {
          'json': {'stringValue': json},
          'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          'v': {'integerValue': '1'},
        },
      }));
      final res = await req.close().timeout(timeout);
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<RemoteDoc?> get(String code) async {
    if (!RemoteConfig.ready) return null;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(_uri(code)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      return parse(body);
    } finally {
      client.close(force: true);
    }
  }

  /// يحوّل مستند Firestore إلى RemoteDoc (أو null لو ناقص).
  static RemoteDoc? parse(String body) {
    final fields = (jsonDecode(body) as Map<String, dynamic>)['fields'] as Map<String, dynamic>?;
    final json = (fields?['json'] as Map<String, dynamic>?)?['stringValue'] as String?;
    final at = (fields?['updatedAt'] as Map<String, dynamic>?)?['timestampValue'] as String?;
    if (json == null) return null;
    return RemoteDoc(json: json, updatedAt: (at == null ? null : DateTime.tryParse(at))?.toLocal() ?? DateTime(2000));
  }
}
