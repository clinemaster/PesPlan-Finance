import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../reports/domain/report_period.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/budget_progress.dart';
import '../providers/budget_providers.dart';
import 'budget_widgets.dart';

/// Everything about one budget, plus the two things you can do to it.
///
/// A sheet rather than a screen: it is a glance — how much is left, what
/// went into it — and a sheet keeps the rest of the month's budgets
/// visible behind it.
class BudgetDetailSheet extends ConsumerWidget {
  const BudgetDetailSheet({required this.progress, super.key});

  final BudgetProgress progress;

  static Future<void> show(BuildContext context, BudgetProgress progress) =>
      AppBottomSheet.show<void>(
        context,
        title: progress.budget.name,
        child: BudgetDetailSheet(progress: progress),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final paint = statusPaint(context, progress.status);
    final budget = progress.budget;

    // A scrolling body with the two actions pinned below it.
    //
    // The breakdown is eight rows plus a note, which is taller than a
    // sheet on a small phone — and a sheet whose Delete button is below
    // the fold is a sheet with no way out but the handle.
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
                Row(
                  children: [
                    CategoryIcon(
                      category: budget.iconKey,
                      size: AppIconSize.huge,
                      tint: paint.surface,
                      iconColor: paint.text,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BudgetStatusChip(status: progress.status),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            progress.isOver ? 'Over by' : 'Left to spend',
                            style: AppTypography.caption.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                          MoneyText(
                            progress.isOver
                                ? progress.overspend
                                : progress.remaining,
                            size: MoneySize.large,
                            colorBySign: false,
                            color: progress.isOver
                                ? paint.text
                                : finance.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                AppProgressBar(
                  value: progress.ratio,
                  color: paint.mark,
                  semanticLabel: progress.status.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  progress.status.explanation,
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _Row(label: 'Budgeted', value: budget.amount.format()),
                const AppDivider(),
                _Row(label: 'Spent', value: progress.spent.format()),
                const AppDivider(),
                _Row(
                  label: progress.isOver ? 'Over by' : 'Remaining',
                  value: progress.isOver
                      ? progress.overspend.format()
                      : progress.remaining.format(),
                ),
                const AppDivider(),
                _Row(label: 'Used', value: '${progress.percent}%'),
                const AppDivider(),
                _Row(
                  label: 'Period',
                  value:
                      '${ReportPeriod.monthName(budget.month)} ${budget.year}',
                ),
                const AppDivider(),
                _Row(
                  label: 'Type',
                  value: budget.isOverall
                      ? 'Overall'
                      : budget.categoryLabel ?? '—',
                ),
                if (budget.description.trim().isNotEmpty) ...[
                  const AppDivider(),
                  _Row(label: 'Note', value: budget.description),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // The transactions behind the figure, reached through the screen
        // that already lists them properly rather than a second list
        // inside this sheet.
        AppButton.text(
          label: progress.transactionCount == 0
              ? 'No spending yet'
              : 'See the '
                    '${progress.transactionCount} '
                    '${progress.transactionCount == 1 ? 'transaction' : 'transactions'}',
          icon: AppIcons.transactions,
          onPressed: progress.transactionCount == 0
              ? null
              : () => _openTransactions(context, ref),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: AppButton.outlined(
                label: 'Edit',
                icon: AppIcons.edit,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.budgetEdit(budget.id));
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton.destructive(
                label: 'Delete',
                icon: AppIcons.delete,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openTransactions(BuildContext context, WidgetRef ref) {
    final budget = progress.budget;
    final period = ReportPeriod.monthOf(budget.year, budget.month);
    final filter = ref.read(transactionFilterProvider.notifier);

    filter
      ..setCategories(
        budget.categoryId == null ? const {} : {budget.categoryId!},
      )
      ..setDateRange(from: period.start, to: period.end);

    Navigator.of(context).pop();
    context.go(Routes.transactions);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final budget = progress.budget;

    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this budget?',
      // Names the budget and its amount: a confirmation that just says
      // "this budget" is one people agree to without reading.
      message:
          'The ${budget.amount.format()} budget for ${budget.name} in '
          '${ReportPeriod.monthName(budget.month)} will be removed. Your '
          'transactions are not affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed != true) return;

    await ref.read(budgetActionsProvider).delete(budget.id);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnackbar.success(context, 'Budget deleted');
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: finance.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                color: finance.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
