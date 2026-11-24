import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/age_band.dart';
import '../../domain/arabic_digits.dart';
import 'onboarding_scaffold.dart';

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// إضافة طفل: لقب (لا اسم حقيقي) + شهر وسنة الميلاد + أفاتار تجريدي.
class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  late final TextEditingController _nick;

  @override
  void initState() {
    super.initState();
    _nick = TextEditingController(text: ref.read(childDraftProvider).nickname);
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  void _update(ChildDraft Function(ChildDraft d) f) {
    final n = ref.read(childDraftProvider.notifier);
    n.state = f(n.state);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(childDraftProvider);
    final age = draft.ageYears();
    final unsupported = age != null && !isSupportedAge(age);
    final thisYear = DateTime.now().year;

    String? ageMessage;
    if (age != null && age < kMinSupportedAge) {
      ageMessage = 'براق مناسب من سنتين فما فوق، نراك قريبًا إن شاء الله.';
    } else if (age != null && age > kMaxSupportedAge) {
      ageMessage = 'براق مخصص حتى ١٤ سنة.';
    }

    return OnboardingScaffold(
      step: 'الخطوة ٢ من ٣',
      title: 'أضف طفلك',
      child: ListView(
        children: [
          Text('اللقب (ليس الاسم الحقيقي)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nick,
            maxLength: 12,
            onChanged: (v) => _update((d) => d.copyWith(nickname: v)),
            decoration: _fieldDecoration('اكتب لقبًا لطيفًا، مثل: نجمة'),
          ),
          const SizedBox(height: 8),
          Text('شهر وسنة الميلاد',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('birth_month'),
                  initialValue: draft.birthMonth,
                  decoration: _fieldDecoration('الشهر'),
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(value: i, child: Text(_months[i - 1])),
                  ],
                  onChanged: (v) => _update((d) => d.copyWith(birthMonth: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('birth_year'),
                  initialValue: draft.birthYear,
                  decoration: _fieldDecoration('السنة'),
                  items: [
                    for (var y = thisYear; y >= thisYear - 17; y--)
                      DropdownMenuItem(
                          value: y, child: Text(toArabicDigits(y))),
                  ],
                  onChanged: (v) => _update((d) => d.copyWith(birthYear: v)),
                ),
              ),
            ],
          ),
          if (ageMessage != null) ...[
            const SizedBox(height: 12),
            Text(ageMessage,
                style: const TextStyle(color: AppColors.terracotta)),
          ],
          const SizedBox(height: 20),
          Text('اختر رمزًا لطفلك',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in Avatars.all.entries)
                _AvatarChip(
                  emoji: e.value,
                  selected: draft.avatar == e.key,
                  onTap: () => _update((d) => d.copyWith(avatar: e.key)),
                ),
            ],
          ),
          const SizedBox(height: 28),
          GoldButton(
            label: 'التالي',
            onPressed: draft.isComplete && !unsupported
                ? () => context.push('/onboarding/band')
                : null,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      );
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.gold : Colors.transparent,
            width: 4,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}
