import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/repositories/settings_repository.dart';
import 'game_content.dart';

/// «نزّلي مرة والعبي على طول»: ألعاب إضافية تُنزَّل من مصدرنا فقط عند وجود إنترنت،
/// وتُحفظ على الجهاز فتُلعب بعدها بلا إنترنت. المحتوى بيانات فقط (لا كود)، ويُتحقق منه قبل الحفظ.
/// لا يفتح أي متصفح ولا روابط أخرى، ولا يرسل أي بيانات عن الطفلتين.
class GamePackService {
  GamePackService(this._settings, {this.url = kGamePackUrl});

  /// ملف حزمة الألعاب الإضافية في مستودع المشروع (يُحدَّث بلا إصدار تطبيق جديد).
  static const kGamePackUrl =
      'https://raw.githubusercontent.com/saaalk4-cmd/Nour-and-fedaa/feature/kids-motivation-v1/assets/content/games_pack.json';
  static const _key = 'game_pack_json';

  final SettingsRepository _settings;
  final String url;

  /// الحزمة المحفوظة على الجهاز (أو null).
  Future<GameCatalog?> saved() async {
    try {
      final raw = await _settings.getValue(_key);
      return raw == null || raw.isEmpty ? null : GameCatalog.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// يحاول تنزيل نسخة أحدث بهدوء. أي فشل (لا إنترنت، ملف غير صالح) يُتجاهل.
  Future<bool> refresh({Duration timeout = const Duration(seconds: 8)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return false;
      final raw = await res.transform(utf8.decoder).join().timeout(timeout);
      if (raw.length > 2 * 1024 * 1024) return false;
      GameCatalog.parse(raw); // يجب أن تكون حزمة صالحة قبل الحفظ
      await _settings.setValue(_key, raw);
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
