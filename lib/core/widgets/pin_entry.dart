import 'package:flutter/material.dart';

import '../../domain/arabic_digits.dart';
import '../theme/app_theme.dart';

/// أربع نقاط ولوحة أرقام ١-٢-٣ من اليسار لليمين.
/// يستدعي [onCompleted] عند اكتمال 4 أرقام ثم يفرّغ الحقل.
class PinEntry extends StatefulWidget {
  const PinEntry({super.key, required this.onCompleted, this.error});

  final ValueChanged<String> onCompleted;
  final String? error;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  String _value = '';

  void _tap(String d) {
    if (_value.length >= 4) return;
    setState(() => _value += d);
    if (_value.length == 4) {
      final done = _value;
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _value = '');
        widget.onCompleted(done);
      });
    }
  }

  void _back() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                key: ValueKey('pin_dot_$i'),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      i < _value.length ? AppColors.gold : Colors.transparent,
                  border: Border.all(color: AppColors.gold, width: 2.5),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 36,
          child: widget.error == null
              ? null
              : Center(
                  child: Text(
                    widget.error!,
                    style: const TextStyle(color: AppColors.terracotta),
                  ),
                ),
        ),
        // لوحة الأرقام لا تُعكس في الاتجاه العربي.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                _KeyRow(children: [
                  for (final d in row) _DigitKey(d, onTap: () => _tap(d)),
                ]),
              _KeyRow(children: [
                const SizedBox(width: 84, height: 72),
                _DigitKey('0', onTap: () => _tap('0')),
                _BackKey(onTap: _back),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center, children: children),
      );
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, {required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('key_$digit'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                toArabicDigits(digit),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackKey extends StatelessWidget {
  const _BackKey({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('key_back'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const SizedBox(
            width: 72,
            height: 72,
            child: Icon(Icons.backspace_outlined, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
