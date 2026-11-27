import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import 'pin_entry.dart';

/// بوابة ولي الأمر قبل أي رابط خارجي (شرط سياسة Google Play للأسر).
Future<bool> askParentPin(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _GateDialog(ref: ref),
  );
  return ok == true;
}

/// يفتح رابطًا خارجيًا بعد رمز ولي الأمر.
Future<void> openExternalForParent(
    BuildContext context, WidgetRef ref, String url) async {
  if (!await askParentPin(context, ref)) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _GateDialog extends StatefulWidget {
  const _GateDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('لولي الأمر', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز ولي الأمر لفتح المصدر خارج التطبيق'),
            const SizedBox(height: 12),
            PinEntry(
              error: _error,
              onCompleted: (pin) async {
                final ok =
                    await widget.ref.read(settingsRepositoryProvider).verifyPin(pin);
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setState(() => _error = 'الرمز غير صحيح');
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
      ],
    );
  }
}
