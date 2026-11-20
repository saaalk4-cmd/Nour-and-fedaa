import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import 'family_code.dart';
import 'remote_config.dart';
import 'remote_sync.dart';
import 'remote_view_screen.dart';

/// مجموعة «المتابعة من تليفون الأهل» في لوحة الأهل.
/// على تليفون البنات: تشغيل الإرسال وعرض كود الأسرة. على أي تليفون: «ده تليفوني، أتابع منه».
class RemoteControls extends ConsumerWidget {
  const RemoteControls({super.key, this.configured});

  /// للاختبار؛ الافتراضي: هل أُعدّت الخدمة في remote_config.dart.
  final bool? configured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(configured ?? RemoteConfig.ready)) {
      return const ListTile(
        leading: Text('📱', style: TextStyle(fontSize: 26)),
        title: Text('المتابعة من تليفونك'),
        subtitle: Text('لسه مش متجهّزة: محتاجة مشروع Firebase (الخطوات في docs/REMOTE_SETUP.md).'),
      );
    }
    final repo = ref.read(settingsRepositoryProvider);
    final on = ref.watch(remoteSyncOnProvider).valueOrNull ?? false;
    final code = ref.watch(familyCodeProvider).valueOrNull;
    final last = ref.watch(lastRemoteSyncProvider).valueOrNull;

    Future<void> refresh() async {
      ref
        ..invalidate(remoteSyncOnProvider)
        ..invalidate(familyCodeProvider)
        ..invalidate(lastRemoteSyncProvider);
    }

    Future<void> sendNow() async {
      final ok = await ref.read(remoteSyncProvider).syncNow();
      await refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'اتبعت ✅' : 'ما اتبعتش: اتأكدي إن التليفون متصل بالنت'),
        ));
      }
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Text('📤', style: TextStyle(fontSize: 26)),
          title: const Text('إرسال التقدم لتليفون الأهل'),
          subtitle: const Text('على تليفون البنات: ملخص أرقام بس (الوقت والدروس والنجوم)، بلا صوت ولا صور. يتبعت لما يكون فيه نت.'),
          value: on,
          onChanged: (v) async {
            if (v && code == null) await repo.setFamilyCode(FamilyCode.generate());
            await repo.setRemoteSyncOn(v);
            await refresh();
            if (v) unawaited(sendNow());
          },
        ),
        if (on && code != null) ...[
          ListTile(
            leading: const Text('🔑', style: TextStyle(fontSize: 26)),
            title: const Text('كود الأسرة'),
            subtitle: SelectableText(
              FamilyCode.pretty(code),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            trailing: IconButton(
              tooltip: 'نسخ',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: FamilyCode.pretty(code)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتنسخ الكود')));
                }
              },
            ),
          ),
          ListTile(
            leading: const Text('🔄', style: TextStyle(fontSize: 26)),
            title: const Text('ابعتي دلوقتي'),
            subtitle: Text(last == null ? 'لسه ما اتبعتش ولا مرة' : 'آخر إرسال: ${ago(last)}'),
            onTap: sendNow,
          ),
          ListTile(
            leading: const Text('♻️', style: TextStyle(fontSize: 26)),
            title: const Text('كود جديد'),
            subtitle: const Text('لو الكود وصل لحد تاني: التليفونات المربوطة بالقديم هتبطّل تشوف.'),
            onTap: () async {
              await repo.setFamilyCode(FamilyCode.generate());
              await refresh();
              unawaited(sendNow());
            },
          ),
        ],
        ListTile(
          leading: const Text('📱', style: TextStyle(fontSize: 26)),
          title: const Text('ده تليفوني: أتابع البنات منه'),
          subtitle: const Text('على تليفونك إنتِ: اكتبي الكود، والتليفون هيفتح على المتابعة على طول (بالـPIN).'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () async {
            final entered = await askFamilyCode(context);
            if (entered == null) return;
            await repo.setFamilyCode(entered);
            await repo.setRemoteSyncOn(false);
            await repo.setDeviceRole('parent');
            ref.invalidate(deviceRoleProvider);
            await refresh();
            if (context.mounted) context.go('/remote');
          },
        ),
      ],
    );
  }
}
