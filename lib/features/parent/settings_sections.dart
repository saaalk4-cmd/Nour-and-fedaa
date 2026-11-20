import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/voice_service.dart';
import '../../data/providers.dart';
import '../../domain/time_guard.dart';
import '../games/game_providers.dart';

/// بطاقة إعدادات بيضاء مدوّرة (نفس مجموعات لوحة الأهل).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// صف بعنوان وخيارات (أزرار مقطّعة) لقيمة واحدة.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.title, this.subtitle, required this.value, required this.options, required this.onChanged});

  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [for (final e in options.entries) ButtonSegment<T>(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 13)))],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// الصوت: وقفة بين الجمل، سرعة الكلام، علو الكلام والمؤثرات، والقراءة التلقائية.
class VoiceControls extends ConsumerWidget {
  const VoiceControls({super.key});

  Future<void> _save(WidgetRef ref, VoiceSettings s) async {
    await ref.read(settingsRepositoryProvider).saveVoiceSettings(s);
    ref.read(voiceServiceProvider).refreshSettings();
    ref.read(soundServiceProvider).effectsVolume = s.effectsVolume;
    ref.invalidate(voiceSettingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(voiceSettingsProvider).valueOrNull ?? const VoiceSettings();
    String near(double v, List<double> xs) => xs.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b).toString();
    return Column(
      children: [
        ChoiceRow<int>(
          title: 'الوقفة بين الجمل',
          subtitle: 'وقت تسمع فيه الطفلة الجملة كاملة قبل التي بعدها',
          value: [500, 1000, 2000].contains(s.pauseMs) ? s.pauseMs : 1000,
          options: const {500: 'نصف ثانية', 1000: 'ثانية', 2000: 'ثانيتان'},
          onChanged: (v) => _save(ref, s.copyWith(pauseMs: v)),
        ),
        ChoiceRow<String>(
          title: 'سرعة الكلام الآلي',
          subtitle: 'تنطبق على الصوت الآلي فقط (تسجيلاتكِ بسرعتها)',
          value: near(s.rate, const [0.35, 0.45, 0.6]),
          options: const {
            '0.35': 'بطيء',
            '0.45': 'عادي',
            '0.6': 'سريع',
          },
          onChanged: (v) async {
            await _save(ref, s.copyWith(rate: double.parse(v)));
            await ref.read(voiceServiceProvider).sayAndWait('هيا نتعلم معًا', pause: false);
          },
        ),
        _VolumeSlider(title: 'علو الكلام', value: s.voiceVolume, onEnd: (v) async {
          await _save(ref, s.copyWith(voiceVolume: v));
          await ref.read(voiceServiceProvider).sayAndWait('هيا نتعلم معًا', pause: false);
        }),
        _VolumeSlider(title: 'علو المؤثرات', value: s.effectsVolume, onEnd: (v) => _save(ref, s.copyWith(effectsVolume: v))),
        SwitchListTile(
          title: const Text('قراءة الدرس تلقائيًا'),
          subtitle: const Text('لو أُغلقت: يُقرأ الدرس عند ضغط 🔊 فقط'),
          value: s.autoRead,
          onChanged: (v) => _save(ref, s.copyWith(autoRead: v)),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.title, required this.value, required this.onEnd});

  final String title;
  final double value;
  final ValueChanged<double> onEnd;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(
            child: Slider(
              value: _drag ?? widget.value,
              min: 0.2,
              max: 1,
              divisions: 8,
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                widget.onEnd(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// الوقت: الحد اليومي، ساعات المنع، ومدة الاستراحة.
class TimeControls extends ConsumerWidget {
  const TimeControls({super.key});

  Future<void> _save(WidgetRef ref, TimeSettings s) async {
    await ref.read(settingsRepositoryProvider).saveTimeSettings(s);
    ref.invalidate(timeSettingsProvider);
  }

  static String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timeSettingsProvider).valueOrNull ?? const TimeSettings();
    Future<void> pick(bool from) async {
      final cur = from ? (s.quietFromMin < 0 ? 20 * 60 : s.quietFromMin) : (s.quietToMin < 0 ? 7 * 60 : s.quietToMin);
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      if (t == null) return;
      final m = t.hour * 60 + t.minute;
      await _save(ref, from ? s.copyWith(quietFromMin: m, quietToMin: s.quietToMin < 0 ? 7 * 60 : s.quietToMin) : s.copyWith(quietToMin: m, quietFromMin: s.quietFromMin < 0 ? 20 * 60 : s.quietFromMin));
    }

    return Column(
      children: [
        ChoiceRow<int>(
          title: 'الحد اليومي لكل طفلة',
          subtitle: 'عند انتهائه تقول لَمعة «يلا نرتاح» بدل أن يُقفل التطبيق فجأة',
          value: const [0, 15, 30, 45, 60].contains(s.dailyLimitMin) ? s.dailyLimitMin : 0,
          options: const {0: 'بلا حد', 15: '15 د', 30: '30 د', 45: '45 د', 60: 'ساعة'},
          onChanged: (v) => _save(ref, s.copyWith(dailyLimitMin: v)),
        ),
        SwitchListTile(
          title: const Text('أوقات لا نلعب فيها'),
          subtitle: Text(s.hasQuietHours ? 'من ${fmt(s.quietFromMin)} إلى ${fmt(s.quietToMin)}' : 'مثلًا بعد الثامنة مساءً'),
          value: s.hasQuietHours,
          onChanged: (v) => _save(ref, v ? s.copyWith(quietFromMin: 20 * 60, quietToMin: 7 * 60) : s.copyWith(quietFromMin: -1, quietToMin: -1)),
        ),
        if (s.hasQuietHours)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => pick(true), child: Text('من ${fmt(s.quietFromMin)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => pick(false), child: Text('إلى ${fmt(s.quietToMin)}'))),
              ],
            ),
          ),
        ChoiceRow<int>(
          title: 'اقتراح استراحة',
          subtitle: 'بعد كم دقيقة لعب متواصل تقترح لَمعة شرب الماء والحركة',
          value: const [10, 15, 20, 30].contains(s.breakEveryMin) ? s.breakEveryMin : 15,
          options: const {10: '10 د', 15: '15 د', 20: '20 د', 30: '30 د'},
          onChanged: (v) => _save(ref, s.copyWith(breakEveryMin: v)),
        ),
      ],
    );
  }
}

/// الألعاب والإنترنت.
class GamesControls extends ConsumerStatefulWidget {
  const GamesControls({super.key});

  @override
  ConsumerState<GamesControls> createState() => _GamesControlsState();
}

class _GamesControlsState extends ConsumerState<GamesControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(settingsRepositoryProvider);
    final games = ref.watch(gamesEnabledProvider).valueOrNull ?? true;
    final mode = ref.watch(packModeProvider).valueOrNull ?? 'auto';
    return Column(
      children: [
        SwitchListTile(
          title: const Text('🎮  الألعاب'),
          subtitle: const Text('إخفاء الألعاب من الشاشة الرئيسية'),
          value: games,
          onChanged: (v) async {
            await repo.setGamesEnabled(v);
            ref.invalidate(gamesEnabledProvider);
          },
        ),
        ChoiceRow<String>(
          title: 'ألعاب جديدة من الإنترنت',
          subtitle: 'تُنزَّل من مستودعنا فقط وتُحفظ للعب بلا إنترنت. لا نرسل أي بيانات عن البنتين.',
          value: mode,
          options: const {'auto': 'تلقائيًا', 'manual': 'بالزر فقط', 'off': 'مقفول'},
          onChanged: (v) async {
            await repo.setPackMode(v);
            ref.invalidate(packModeProvider);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _busy || mode == 'off'
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _busy = true);
                      final ok = await ref.read(gamePackServiceProvider).refresh();
                      if (ok) ref.invalidate(gameCatalogProvider);
                      if (!mounted) return;
                      setState(() => _busy = false);
                      messenger.showSnackBar(SnackBar(content: Text(ok ? 'تم تحديث الألعاب' : 'لا توجد ألعاب جديدة الآن (أو لا يوجد إنترنت)')));
                    },
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(_busy ? 'جارٍ البحث…' : 'دوّري على ألعاب جديدة الآن'),
            ),
          ),
        ),
      ],
    );
  }
}

/// الشكل والعرض + الأمان.
class DisplayControls extends ConsumerWidget {
  const DisplayControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(settingsRepositoryProvider);
    final reduce = ref.watch(reduceMotionProvider).valueOrNull ?? false;
    final scale = ref.watch(fontScaleProvider).valueOrNull ?? 1.0;
    final songButton = ref.watch(songButtonProvider).valueOrNull ?? true;
    final songAfter = ref.watch(songAfterAdventureProvider).valueOrNull ?? true;
    final homeMap = ref.watch(homeMapProvider).valueOrNull ?? false;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Text('🗺️', style: TextStyle(fontSize: 26)),
          title: const Text('«عالمي» كخريطة مرسومة'),
          subtitle: const Text('الأقسام محطات على طريق بدل المربعات'),
          value: homeMap,
          onChanged: (v) async {
            await repo.setHomeMap(v);
            ref.invalidate(homeMapProvider);
          },
        ),
        SwitchListTile(
          secondary: const Text('🎵', style: TextStyle(fontSize: 26)),
          title: const Text('زر «أغنيتنا» في الرئيسية'),
          subtitle: const Text('البنت تسمع أغنية فداء ونور وقت ما تحب'),
          value: songButton,
          onChanged: (v) async {
            await repo.setSongButton(v);
            ref.invalidate(songButtonProvider);
          },
        ),
        SwitchListTile(
          secondary: const Text('🎉', style: TextStyle(fontSize: 26)),
          title: const Text('الأغنية بعد مغامرة اليوم'),
          subtitle: const Text('تشتغل وحدها مرة واحدة احتفالًا لما تنهي البنت مغامرة اليوم'),
          value: songAfter,
          onChanged: (v) async {
            await repo.setSongAfterAdventure(v);
            ref.invalidate(songAfterAdventureProvider);
          },
        ),
        SwitchListTile(
          title: const Text('تقليل الحركة'),
          subtitle: const Text('بلا كونفيتي ولا رقص، للبنت التي تتشتت من الحركة'),
          value: reduce,
          onChanged: (v) async {
            await repo.setReduceMotion(v);
            ref.invalidate(reduceMotionProvider);
          },
        ),
        ChoiceRow<double>(
          title: 'حجم الخط',
          value: scale >= 1.15 ? 1.2 : 1.0,
          options: {1.0: 'عادي', 1.2: 'كبير'},
          onChanged: (v) async {
            await repo.setFontScale(v);
            ref.invalidate(fontScaleProvider);
          },
        ),
        ListTile(
          leading: const Text('🎬', style: TextStyle(fontSize: 26)),
          title: const Text('مشاهدة فيلم المقدمة'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => context.push('/intro'),
        ),
        ListTile(
          leading: const Text('🔑', style: TextStyle(fontSize: 26)),
          title: const Text('تغيير رمز PIN'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => _changePin(context, ref),
        ),
      ],
    );
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(settingsRepositoryProvider);
    final hasPin = await repo.hasPin();
    final old = TextEditingController(), a = TextEditingController(), b = TextEditingController();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget field(TextEditingController c, String label) => TextField(
                controller: c,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: label, counterText: ''),
              );
          return AlertDialog(
            title: const Text('تغيير رمز PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPin) field(old, 'الرمز الحالي'),
                field(a, 'الرمز الجديد (4 أرقام)'),
                field(b, 'أعيدي كتابة الرمز الجديد'),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Color(0xFFB3261E)))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  if (hasPin && !await repo.verifyPin(old.text)) {
                    setS(() => error = 'الرمز الحالي غير صحيح');
                    return;
                  }
                  if (a.text.length != 4 || a.text != b.text) {
                    setS(() => error = 'الرمزان يجب أن يكونا 4 أرقام متطابقة');
                    return;
                  }
                  await repo.setPin(a.text);
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    if (done == true) messenger.showSnackBar(const SnackBar(content: Text('تم تغيير الرمز')));
  }
}
