import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/dashboard_data.dart';

/// How the month's spending sits against the budget.
///
/// One rolled-up figure, not six category bars: the dashboard's job is to
/// say whether things are fine, and the breakdown is a tap away in Budgets.
/// A user who needs the detail knows where it is; one who does not should
/// not have to scroll past it.
class BudgetOverviewSection extends StatelessWidget {
  const BudgetOverviewSection({required this.budget, super.key});

  /// Null when no budget is set — the section renders an invitation rather
  /// than a zeroed progress bar, which would read as "you have spent
  /// nothing" instead of "you have not set one".
  final BudgetOverview? budget;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final current = budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Budget',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.budgets),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (current == null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No budget set',
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Set a monthly limit and this card will show how much of '
                  'it is left.',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            onTap: () => context.go(Routes.budgets),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monthly budget',
                        style: AppTypography.titleCard.copyWith(
                          color: finance.textPrimary,
                        ),
                      ),
                    ),
                    StatusIndicator(
                      label: current.status.label,
                      tone: switch (current.status) {
                        BudgetStatus.comfortable => StatusTone.success,
                        BudgetStatus.closeToLimit => StatusTone.warning,
                        BudgetStatus.overBudget => StatusTone.error,
                      },
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Stacked, not side by side. Two seven-digit shilling
                // amounts on one line overflow a phone by about 200px, and
                // at a large text scale they would overflow any phone.
                // Neutral ink, not sign colouring. `spent` is a positive
                // magnitude, so the default would paint it income-green —
                // telling the user they earned their budget rather than
                // spent it. Spending against a limit is a quantity, not a
                // direction.
                MoneyText(
                  current.spent,
                  size: MoneySize.large,
                  colorBySign: false,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'of ${current.limit.format()}',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Coloured from the card's own status rather than the
                // component's default thresholds.
                //
                // AppProgressBar turns amber at 80% of its own accord,
                // while this card calls 77% "Close to limit" — the
                // budgets feature's earlier warning, folded into three
                // levels here. Left to the default, the chip and the bar
                // disagreed between 75% and 80%.
                AppProgressBar(
                  value: current.ratio,
                  color: switch (current.status) {
                    BudgetStatus.overBudget => finance.expense,
                    BudgetStatus.closeToLimit => finance.warning,
                    BudgetStatus.comfortable => context.colors.primary,
                  },
                  semanticLabel:
                      '${current.spent.semanticLabel} spent of '
                      '${current.limit.semanticLabel}',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        current.remaining.isNegative
                            ? '${current.remaining.format()} over'
                            : '${current.remaining.format()} left',
                        style: AppTypography.bodySmall.copyWith(
                          color: current.remaining.isNegative
                              ? finance.expenseText
                              : finance.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Across ${current.categoryCount} categories',
                      style: AppTypography.caption.copyWith(
                        color: finance.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
