import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/account_deletion.dart';
import '../../data/providers.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/content_catalog.dart';
import '../../domain/age_band.dart';

final contentCatalogProvider = FutureProvider.autoDispose<List<SourceEntry>>(
  (ref) => ContentCatalog().entries(),
);

/// قسم الوالدين: المنهج، المصادر وحالة المراجعة، الخصوصية، والأمان.
class ParentsCornerScreen extends ConsumerWidget {
  const ParentsCornerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final catalog = ref.watch(contentCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('قسم الوالدين')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('منهج براق', style: t.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'مسار واحد من سنتين إلى ١٤ سنة. العمر يحدد شكل التطبيق، واختبار قصير يحدد نقطة البداية، ويمكنك تغيير الفئة من لوحتك في أي وقت.'),
          const SizedBox(height: 8),
          for (final b in AgeBand.values)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(b.label),
              subtitle: Text(b.rangeLabel),
            ),
          const Divider(height: 32),
          Text('المصادر وحالة المراجعة', style: t.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'لكل محتوى ديني مصدر معلن. «قيد المراجعة» يعني أنه لم يُعتمد بعد من مراجع شرعي. لا نكتب نص القرآن يدويًا، بل نستورده من مصدر مرخّص ونتحقق منه.'),
          const SizedBox(height: 8),
          catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('تعذّر تحميل سجل المصادر'),
            data: (list) => Column(
              children: [for (final e in list) _SourceTile(entry: e)],
            ),
          ),
          const Divider(height: 32),
          Text('الخلاف الفقهي', style: t.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'نقتصر في هذه المرحلة على ما اتُّفق عليه وما ثبت بمصدره، ونؤجل المسائل الخلافية إلى أن يُحدَّد المراجع الشرعي.'),
          const Divider(height: 32),
          Text('الخصوصية', style: t.titleLarge),
          const SizedBox(height: 8),
          const Text(
              '• لا إعلانات ولا تتبّع.\n'
              '• نحفظ لقب الطفل (لا اسمه الحقيقي) وشهر وسنة الميلاد فقط.\n'
              '• لا موقع دقيق ولا معرّفات جهاز.\n'
              '• حساب ولي الأمر هو الأساس، وإعدادات الطفل خلف رمزك السري.'),
          const Divider(height: 32),
          Text('الحساب', style: t.titleLarge),
          const SizedBox(height: 8),
          ref.watch(accountProvider).maybeWhen(
                data: (a) => Text(a == null
                    ? 'لا يوجد حساب'
                    : a.isLocal
                        ? 'وضع تجريبي على هذا الجهاز: ${a.email ?? ''}'
                        : 'مسجّل الدخول: ${a.email ?? ''}'),
                orElse: () => const SizedBox.shrink(),
              ),
          TextButton.icon(
            key: const Key('sign_out'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج؟'),
                  content: const Text(
                      'ملفات الأطفال وتقدّمهم تبقى على هذا الجهاز.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('تراجع')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('خروج')),
                  ],
                ),
              );
              if (ok != true) return;
              await ref.read(accountRepositoryProvider).signOut();
              ref.invalidate(accountProvider);
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
          TextButton.icon(
            key: const Key('delete_account'),
            onPressed: () => _deleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف الحساب وكل البيانات'),
          ),
          const Divider(height: 32),
          ListTile(
            key: const Key('change_pin_tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('تغيير الرمز السري'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/parent/pin'),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final password = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف الحساب نهائيًا؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'سيُحذف حساب ولي الأمر، وملفات كل الأطفال وتقدّمهم من السحابة ومن هذا الجهاز. لا يمكن التراجع.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('delete_password'),
            controller: password,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'كلمة المرور للتأكيد'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع')),
        TextButton(
            key: const Key('confirm_delete_account'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي')),
      ],
    ),
  );
  final pw = password.text;
  password.dispose();
  if (ok != true || !context.mounted) return;
  try {
    final accounts = ref.read(accountRepositoryProvider);
    await deleteFamilyAccount(
      accounts: accounts,
      store: accounts.isReal ? ref.read(cloudStoreProvider) : null,
      password: pw,
    );
    ref.read(selectedChildIdProvider.notifier).state = null;
    ref.invalidate(accountProvider);
    ref.invalidate(childrenProvider);
    if (context.mounted) context.go('/');
  } on AccountException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.entry});

  final SourceEntry entry;

  @override
  Widget build(BuildContext context) {
    final types = entry.sourceTypes
        .map((s) => sourceTypeLabels[s] ?? s)
        .join('، ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Chip(
                  label: Text(entry.verified ? 'تمت المراجعة' : 'قيد المراجعة'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text('النوع: $types${entry.note == null ? '' : ' • ${entry.note}'}'),
            if (entry.sources.isNotEmpty)
              Text('المصدر: ${entry.sources.join('، ')}'),
            if (entry.audioStatus != null) Text('الصوت: ${entry.audioStatus}'),
          ],
        ),
      ),
    );
  }
}
