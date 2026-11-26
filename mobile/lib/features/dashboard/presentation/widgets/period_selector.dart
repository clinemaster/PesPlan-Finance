import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/dashboard_period.dart';
import '../providers/dashboard_providers.dart';

/// Which window the figures below describe.
///
/// Three visible options rather than a dropdown: the choice changes every
/// number on the screen, so it should be visible without a tap, and a user
/// should be able to see what the alternatives are before committing.
///
/// "Custom" opens the platform range picker rather than inventing a second
/// calendar — the system one already handles locale, month boundaries and
/// accessibility.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodProvider);

    return Semantics(
      label: 'Summary period',
      child: Row(
        children: [
          Expanded(
            child: _PeriodChip(
              label: 'This month',
              isSelected: selected.kind == PeriodKind.thisMonth,
              onTap: () => ref
                  .read(selectedPeriodProvider.notifier)
                  .select(const DashboardPeriod.thisMonth()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PeriodChip(
              label: 'This year',
              isSelected: selected.kind == PeriodKind.thisYear,
              onTap: () => ref
                  .read(selectedPeriodProvider.notifier)
                  .select(const DashboardPeriod.thisYear()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PeriodChip(
              // Once a range is chosen the chip shows it, so the dashboard
              // never leaves "Custom" standing for dates the user cannot
              // see without reopening the picker.
              label: selected.kind == PeriodKind.custom
                  ? selected.describe()
                  : 'Custom',
              isSelected: selected.kind == PeriodKind.custom,
              icon: AppIcons.calendar,
              onTap: () => _pickRange(context, ref, selected),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    DashboardPeriod current,
  ) async {
    final now = ref.read(clockProvider)();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: current.kind == PeriodKind.custom
          ? DateTimeRange(start: current.start!, end: current.end!)
          : null,
      helpText: 'Select a period',
    );

    if (picked == null) return;

    ref
        .read(selectedPeriodProvider.notifier)
        .select(DashboardPeriod.custom(start: picked.start, end: picked.end));
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final foreground = isSelected
        ? context.colors.onPrimary
        : finance.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? context.colors.primary : finance.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: Container(
            // Full touch height even though the chip reads as small: a
            // 32px target is a miss waiting to happen on a bus.
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppIconSize.sm, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
