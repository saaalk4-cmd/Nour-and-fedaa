import 'package:flutter/material.dart';

import 'sections.dart';

/// شاشة مؤقتة لكل قسم إلى أن يُبنى محتواه في المراحل التالية.
class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context) {
    final s = sectionById(sectionId);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text('قريبًا إن شاء الله',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
