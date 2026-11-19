import 'package:flutter_tts/flutter_tts.dart';

import 'voice_service.dart';

/// صوت عربي على الجهاز (اسم + لغة + معلومات الجودة).
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.quality = 0, this.needsNetwork = false});

  final String name;
  final String locale;

  /// جودة أندرويد (300 عادي، 400 عالي، 500 عالي جدًا) أو 0 لو غير معروفة.
  final int quality;
  final bool needsNetwork;

  bool get isArabic => locale.toLowerCase().startsWith('ar');

  /// يقرأ وصف الصوت كما يرجعه flutter_tts (القيم تأتي نصوصًا أحيانًا).
  static TtsVoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString();
    final locale = raw['locale']?.toString();
    if (name == null || locale == null) return null;
    final q = raw['quality']?.toString().toLowerCase() ?? '';
    final quality = int.tryParse(q) ??
        (q.contains('very') ? 500 : q.contains('high') ? 400 : q.contains('normal') ? 300 : 0);
    final net = raw['network_required']?.toString().toLowerCase();
    return TtsVoice(name: name, locale: locale, quality: quality, needsNetwork: net == '1' || net == 'true');
  }

  /// أفضل صوت عربي: الذي اختاره الأهل إن وُجد، وإلا الذي يعمل بلا إنترنت بأعلى جودة.
  static TtsVoice? pick(List<TtsVoice> voices, {String? preferred}) {
    final ar = voices.where((v) => v.isArabic).toList();
    if (ar.isEmpty) return null;
    if (preferred != null) {
      for (final v in ar) {
        if (v.name == preferred) return v;
      }
    }
    int score(TtsVoice v) => (v.needsNetwork ? 0 : 1000) + v.quality;
    ar.sort((a, b) => score(b).compareTo(score(a)));
    return ar.first;
  }
}

/// تنفيذ النطق بصوت النظام العربي (هادئ ولطيف للأطفال). يعمل بلا إنترنت
/// إذا كان صوت عربي منزَّلًا على الجهاز. يختار تلقائيًا أوضح صوت متاح.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTtsEngine({this.preferredVoice});

  /// اسم الصوت الذي اختاره الأهل (من الإعدادات)، أو null للاختيار التلقائي.
  final Future<String?> Function()? preferredVoice;

  FlutterTts? _tts;
  Future<void>? _init;

  Future<List<TtsVoice>> arabicVoices() async {
    try {
      final raw = await (_tts ??= FlutterTts()).getVoices;
      final list = raw is List ? raw : const <Object?>[];
      final voices = [for (final v in list) TtsVoice.fromMap(v)].whereType<TtsVoice>();
      return voices.where((v) => v.isArabic).toList()..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return const [];
    }
  }

  /// يعيد اختيار الصوت (بعد تغيير الأهل له).
  void reset() => _init = null;

  Future<FlutterTts> _ready() async {
    final tts = _tts ??= FlutterTts();
    _init ??= () async {
      await tts.setLanguage('ar');
      try {
        final preferred = await preferredVoice?.call();
        final best = TtsVoice.pick(await arabicVoices(), preferred: preferred);
        if (best != null) await tts.setVoice({'name': best.name, 'locale': best.locale});
      } catch (_) {
        // نكمل بالصوت الافتراضي.
      }
      await tts.setSpeechRate(0.45);
      await tts.setPitch(1.08);
      await tts.setVolume(1.0);
      await tts.awaitSpeakCompletion(false);
    }();
    await _init;
    return tts;
  }

  @override
  Future<void> speak(String text) async => (await _ready()).speak(text);

  @override
  Future<void> stop() async => (await _ready()).stop();
}
