import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// ينطق [text] مرة واحدة عند ظهور الشاشة، ليسمع الطفل ما فيها دون قراءة.
/// نصوص تعليمية قصيرة فقط (لا آيات ولا أحاديث). يحترم مفتاح الصوت في لوحة الأهل.
class SpeakOnOpen extends ConsumerStatefulWidget {
  const SpeakOnOpen({super.key, required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  ConsumerState<SpeakOnOpen> createState() => _SpeakOnOpenState();
}

class _SpeakOnOpenState extends ConsumerState<SpeakOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceServiceProvider).speak(widget.text);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
