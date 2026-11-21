import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/art.dart';
import '../../core/design/kit.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';

/// صفحة «العب مع لمعة» أونلاين (games_web/ على GitHub Pages): ألعاب وحكايات تتحدث بدون نسخة جديدة من التطبيق.
const kOnlineGamesUrl = 'https://saaalk4-cmd.github.io/Nour-and-fedaa/';

/// الرابط لبنت معينة (الصفحة تفتح على ألعابها مباشرة).
Uri onlineGamesUri(Child? c) {
  final who = c == null ? null : (c.name.contains('فداء') || c.age >= 5 ? 'fedaa' : 'nour');
  return Uri.parse(kOnlineGamesUrl).replace(queryParameters: who == null ? null : {'child': who});
}

/// تفتح الصفحة داخل التطبيق نفسه (البنت ماتحسش إنها خرجت)، وزر البيت يرجّعها.
class OnlineGamesScreen extends ConsumerStatefulWidget {
  const OnlineGamesScreen({super.key});

  @override
  ConsumerState<OnlineGamesScreen> createState() => _OnlineGamesScreenState();
}

class _OnlineGamesScreenState extends ConsumerState<OnlineGamesScreen> {
  WebViewController? _web;
  bool _loading = true;
  bool _offline = false;

  void _open(Child? c) {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Kid.sky)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            if (mounted) setState(() => _offline = true);
            ref.read(voiceServiceProvider).speak('لا يوجد إنترنت الآن');
          }
        },
      ))
      ..loadRequest(onlineGamesUri(c));
  }

  void _close() => context.canPop() ? context.pop() : context.go('/world');

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider).valueOrNull;
    if (_web == null && ref.watch(selectedChildProvider).hasValue) _open(child);
    final web = _web;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (web != null && !_offline && await web.canGoBack()) {
          await web.goBack();
        } else {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: Kid.sky,
        body: SafeArea(
          child: Stack(
            children: [
              if (web != null && !_offline) Positioned.fill(child: WebViewWidget(controller: web)),
              if (_offline)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const ArtImage(Art.lamaaThink, width: 170, height: 170),
                    const SizedBox(height: 12),
                    const OutlineText('لا يوجد إنترنت الآن', size: 30, maxLines: 1),
                    const SizedBox(height: 18),
                    PicButton(Art.icRepeat, size: 84, label: 'جرّبي تاني', onTap: () {
                      setState(() {
                        _offline = false;
                        _loading = true;
                      });
                      _open(child);
                    }),
                  ]),
                )
              else if (_loading)
                const Center(child: ArtImage(Art.lamaaWelcome, width: 160, height: 160)),
              // زر البيت: يرجع للتطبيق في أي وقت.
              PositionedDirectional(
                bottom: 14,
                end: 14,
                child: PicButton(Art.icHome, size: 58, label: 'رجوع للتطبيق', onTap: _close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
