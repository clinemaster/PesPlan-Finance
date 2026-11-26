import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/time/clock.dart';
import '../../domain/date_labels.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_category.dart';
import '../../domain/transaction_filter.dart';
import '../providers/transaction_providers.dart';

/// The filter sheet: type, categories and a date range.
///
/// A sheet rather than a row of controls on the screen, because filtering
/// is occasional and the list is what the screen is for. The type chips
/// stay outside on the screen itself — that one is used constantly and
/// should not cost a sheet.
///
/// Edits apply as they are made rather than on an "Apply" button. The list
/// is right behind the sheet, so the effect is visible immediately, and an
/// apply step mostly produces sheets people forget to confirm.
class TransactionFilterSheet extends ConsumerWidget {
  const TransactionFilterSheet({super.key});

  static Future<void> show(BuildContext context) => AppBottomSheet.show<void>(
    context,
    title: 'Filter transactions',
    child: const TransactionFilterSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final controller = ref.read(transactionFilterProvider.notifier);
    final finance = context.finance;

    // The facets scroll; the actions stay pinned. With fifteen category
    // chips the content is taller than a phone, and a Done button that
    // scrolls off the bottom is a sheet the user cannot finish with.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Type'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    _Chip(
                      label: 'All',
                      isSelected: filter.type == null,
                      onTap: () => controller.setType(null),
                    ),
                    for (final type in TransactionType.values)
                      _Chip(
                        label: type.label,
                        isSelected: filter.type == type,
                        onTap: () => controller.setType(type),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    Expanded(child: _Label('Categories')),
                    if (filter.categoryIds.isNotEmpty)
                      AppButton.text(
                        label: 'Clear',
                        size: AppButtonSize.small,
                        onPressed: () => controller.setCategories(const {}),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    // Deduplicated by id: "Other" exists on both sides of the
                    // ledger, and two identical chips would be a puzzle.
                    for (final id in _categoryIds(filter.type))
                      _Chip(
                        label: _labelFor(id),
                        icon: AppIcons.forCategory(id),
                        isSelected: filter.categoryIds.contains(id),
                        onTap: () => controller.toggleCategory(id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    Expanded(child: _Label('Date range')),
                    if (filter.hasDateRange)
                      AppButton.text(
                        label: 'Clear',
                        size: AppButtonSize.small,
                        onPressed: controller.clearDateRange,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton.outlined(
                  label: DateLabels.range(filter.from, filter.to),
                  icon: AppIcons.calendar,
                  onPressed: () => _pickRange(context, ref, filter),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Row(
          children: [
            Expanded(
              child: AppButton.text(
                label: 'Clear all filters',
                onPressed: filter.hasFilters
                    ? () {
                        controller.clearFilters();
                        Navigator.of(context).pop();
                      }
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton.primary(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        Text(
          'Filters change the list and the totals above it.',
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
      ],
    );
  }

  /// Category ids offered, narrowed to the chosen type when there is one.
  static List<String> _categoryIds(TransactionType? type) {
    final source = type == null
        ? TransactionCategories.all
        : TransactionCategories.forType(type);

    final seen = <String>{};
    return [
      for (final category in source)
        if (seen.add(category.id)) category.id,
    ];
  }

  static String _labelFor(String id) {
    for (final category in TransactionCategories.all) {
      if (category.id == id) return category.label;
    }
    return id;
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    TransactionFilter filter,
  ) async {
    final now = ref.read(clockProvider)();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: filter.from != null && filter.to != null
          ? DateTimeRange(start: filter.from!, end: filter.to!)
          : null,
      helpText: 'Filter by date',
    );
    if (picked == null) return;

    ref
        .read(transactionFilterProvider.notifier)
        .setDateRange(from: picked.start, to: picked.end);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.label.copyWith(color: context.finance.textPrimary),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
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
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Center with widthFactor 1, not `alignment: center`.
            //
            // These chips sit in a Wrap, which hands each child unbounded
            // width — and a Container with an alignment takes all the width
            // it is offered. The result is one full-width chip per row
            // instead of a wrapped set. widthFactor makes it shrink to the
            // label while still centring vertically inside the touch target.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppIconSize.sm, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
