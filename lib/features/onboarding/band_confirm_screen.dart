import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/providers.dart';
import '../../domain/age_band.dart';
import 'onboarding_scaffold.dart';

/// تأكيد المسار المقترح من العمر، مع إمكانية اختيار مسار آخر.
class BandConfirmScreen extends ConsumerStatefulWidget {
  const BandConfirmScreen({super.key});

  @override
  ConsumerState<BandConfirmScreen> createState() => _BandConfirmScreenState();
}

class _BandConfirmScreenState extends ConsumerState<BandConfirmScreen> {
  AgeBand? _chosen;
  bool _saving = false;

  AgeBand _suggested() {
    final age = ref.read(childDraftProvider).ageYears() ?? kMinSupportedAge;
    return bandForAge(age);
  }

  Future<void> _confirm() async {
    final suggested = _suggested();
    final band = _chosen ?? suggested;
    setState(() => _saving = true);
    final repo = ref.read(childRepositoryProvider);
    final id = await repo.add(
      ref.read(childDraftProvider),
      bandOverride: band == suggested ? null : band,
    );
    ref.read(selectedChildIdProvider.notifier).state = id;
    ref.invalidate(childrenProvider);
    ref.read(childDraftProvider.notifier).state = const ChildDraft();
    if (mounted) context.go('/onboarding/level');
  }

  @override
  Widget build(BuildContext context) {
    final suggested = _suggested();
    final current = _chosen ?? suggested;
    return OnboardingScaffold(
      title: 'نقترح لطفلك مسار ${suggested.label}',
      subtitle: 'يمكنك اختيار مسار آخر',
      child: Column(
        children: [
          for (final b in AgeBand.values) ...[
            _BandCard(
              band: b,
              selected: b == current,
              onTap: () => setState(() => _chosen = b),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'تأكيد',
              onPressed: _saving ? null : _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandCard extends StatelessWidget {
  const _BandCard({
    required this.band,
    required this.selected,
    required this.onTap,
  });

  final AgeBand band;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF4E3C0) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('band_${band.name}'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.gold : Colors.black26,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${band.rangeLabel} — ${band.label}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
