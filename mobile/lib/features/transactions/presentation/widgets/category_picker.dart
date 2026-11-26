import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_category.dart';

/// Pick a category by tapping its icon.
///
/// A grid of labelled icons rather than a dropdown. The list is short
/// enough to show whole, which means one tap instead of open-scroll-tap,
/// and the icons are the same ones the list rows use — so choosing here
/// teaches the user to read the list later.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    required this.type,
    required this.selectedId,
    required this.onSelected,
    super.key,
    this.error,
  });

  final TransactionType type;
  final String? selectedId;
  final ValueChanged<TransactionCategory> onSelected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final categories = TransactionCategories.forType(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Category',
              style: AppTypography.label.copyWith(color: finance.textPrimary),
            ),
            Text(
              ' *',
              style: AppTypography.label.copyWith(color: finance.expenseText),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in categories)
              _CategoryTile(
                category: category,
                isSelected: category.id == selectedId,
                onTap: () => onSelected(category),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error!,
            style: AppTypography.caption.copyWith(color: finance.expenseText),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final TransactionCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final primary = context.colors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? primary : finance.surfaceMuted,
        borderRadius: AppRadius.cardAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: Container(
            width: 92,
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.xs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.forCategory(category.id),
                  size: AppIconSize.lg,
                  color: isSelected
                      ? context.colors.onPrimary
                      : finance.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? context.colors.onPrimary
                        : finance.textSecondary,
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

/// Expense or income, as two halves of one control.
///
/// Side by side and both visible, because it is the choice that changes
/// everything else on the form — the categories offered, the colour of the
/// amount, the meaning of the record. A dropdown would hide half of a
/// two-option decision behind a tap.
class TransactionTypeSelector extends StatelessWidget {
  const TransactionTypeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      children: [
        for (final type in TransactionType.values) ...[
          if (type != TransactionType.values.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TypeHalf(
              type: type,
              isSelected: value == type,
              // Each side wears its own semantic colour when chosen, so
              // the form says "expense" in the same language the list
              // does.
              surface: type.isIncome
                  ? finance.incomeSurface
                  : finance.expenseSurface,
              foreground: type.isIncome
                  ? finance.incomeText
                  : finance.expenseText,
              onTap: () => onChanged(type),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeHalf extends StatelessWidget {
  const _TypeHalf({
    required this.type,
    required this.isSelected,
    required this.surface,
    required this.foreground,
    required this.onTap,
  });

  final TransactionType type;
  final bool isSelected;
  final Color surface;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      button: true,
      selected: isSelected,
      label: type.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? surface : finance.surfaceMuted,
        borderRadius: AppRadius.buttonAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.buttonAll,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.buttonAll,
              border: Border.all(
                color: isSelected ? foreground : finance.border,
                width: isSelected ? AppStroke.focus : AppStroke.hairline,
              ),
            ),
            child: Container(
              height: AppSpacing.controlHeight,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.isIncome ? AppIcons.income : AppIcons.expense,
                    size: AppIconSize.md,
                    color: isSelected ? foreground : finance.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    type.label,
                    style: AppTypography.button.copyWith(
                      color: isSelected ? foreground : finance.textSecondary,
                    ),
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
