import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/budget_progress.dart';
import '../../domain/budget_status.dart';

/// The colours and icon a status wears.
///
/// One function rather than a switch in each widget. The status, the bar
/// and the chip then cannot disagree — which is how a screen ends up with
/// an amber label above a green bar.
({Color mark, Color text, Color surface, IconData icon}) statusPaint(
  BuildContext context,
  BudgetStatus status,
) {
  final finance = context.finance;

  return switch (status) {
    BudgetStatus.onTrack => (
      mark: finance.success,
      text: finance.successText,
      surface: finance.successSurface,
      icon: AppIcons.success,
    ),
    // Approaching is deliberately the quiet one. Amber at 75% of a budget
    // trains people to ignore amber.
    BudgetStatus.approaching => (
      mark: context.colors.primary,
      text: finance.infoText,
      surface: finance.infoSurface,
      icon: AppIcons.info,
    ),
    BudgetStatus.nearLimit => (
      mark: finance.warning,
      text: finance.warningText,
      surface: finance.warningSurface,
      icon: AppIcons.warning,
    ),
    BudgetStatus.over => (
      mark: finance.expense,
      text: finance.expenseText,
      surface: finance.expenseSurface,
      icon: AppIcons.error,
    ),
  };
}

/// A small status badge.
class BudgetStatusChip extends StatelessWidget {
  const BudgetStatusChip({
    required this.status,
    super.key,
    this.compact = false,
  });

  final BudgetStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paint = statusPaint(context, status);

    return Semantics(
      label: status.label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: paint.surface,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paint.icon, size: AppIconSize.sm, color: paint.text),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(color: paint.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The month's overall budget, at a glance.
///
/// Remaining is the headline rather than spent: "how much is left" is the
/// question someone standing in a shop is actually asking, and it is the
/// number that changes what they do next.
class OverallBudgetCard extends StatelessWidget {
  const OverallBudgetCard({
    required this.progress,
    required this.onTap,
    super.key,
  });

  final BudgetProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final paint = statusPaint(context, progress.status);

    return AppCard(
      onTap: onTap,
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
              BudgetStatusChip(status: progress.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            progress.isOver ? 'Over by' : 'Left to spend',
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          MoneyText(
            progress.isOver ? progress.overspend : progress.remaining,
            size: MoneySize.hero,
            colorBySign: false,
            color: progress.isOver ? paint.text : finance.textPrimary,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Coloured from the budget's own status, not left to the
          // component's default thresholds.
          //
          // AppProgressBar turns amber at 80% of its own accord, while
          // this feature calls 80% "Approaching limit" and paints its
          // chip blue — so the default left an amber bar under a blue
          // label on the same card. The status decides the colour, in
          // one place, for the bar, the chip and the percentage alike.
          AppProgressBar(
            value: progress.ratio,
            color: paint.mark,
            semanticLabel:
                '${progress.spent.semanticLabel} spent of '
                '${progress.budget.amount.semanticLabel}',
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: Text(
                  '${progress.spent.format()} of '
                  '${progress.budget.amount.format()}',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              Text(
                '${progress.percent}%',
                style: AppTypography.label.copyWith(color: paint.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One category budget in the list.
class CategoryBudgetRow extends StatelessWidget {
  const CategoryBudgetRow({
    required this.progress,
    required this.onTap,
    super.key,
  });

  final BudgetProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final paint = statusPaint(context, progress.status);

    return Semantics(
      button: true,
      label:
          '${progress.budget.name}, ${progress.spent.semanticLabel} of '
          '${progress.budget.amount.semanticLabel}, ${progress.status.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  CategoryIcon(
                    category: progress.budget.iconKey,
                    size: AppIconSize.xl,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.budget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: finance.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${progress.spent.format()} of '
                          '${progress.budget.amount.format()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: finance.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${progress.percent}%',
                    style: AppTypography.label.copyWith(color: paint.text),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(
                value: progress.ratio,
                color: paint.mark,
                semanticLabel: progress.budget.name,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.isOver
                          ? '${progress.overspend.format()} over'
                          : '${progress.remaining.format()} left',
                      style: AppTypography.caption.copyWith(
                        color: progress.isOver
                            ? paint.text
                            : finance.textTertiary,
                      ),
                    ),
                  ),
                  // Only the levels worth acting on carry a badge. A chip
                  // on every row makes all of them wallpaper.
                  if (progress.status.needsAttention)
                    BudgetStatusChip(status: progress.status, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Month back, month forward.
class BudgetMonthStepper extends StatelessWidget {
  const BudgetMonthStepper({
    required this.title,
    required this.onPrevious,
    required this.onNext,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onPrevious;

  /// Null disables it. Forward is dimmed rather than hidden at the
  /// present edge: a control that vanishes reads as a bug.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      children: [
        AppIconButton(
          icon: AppIcons.back,
          tooltip: 'Previous month',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleCard.copyWith(
                  color: finance.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        AppIconButton(
          icon: AppIcons.forward,
          tooltip: 'Next month',
          onPressed: onNext,
        ),
      ],
    );
  }
}
