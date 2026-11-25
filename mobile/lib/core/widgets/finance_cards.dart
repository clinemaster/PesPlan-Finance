import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import '../money/money.dart';
import 'app_card.dart';
import 'app_display.dart';

/// The hero card at the top of the home screen.
///
/// One figure, large, with its label above and supporting detail below. The
/// balance is the single thing a user opens the app to see, so it gets the
/// hero type style and nothing competes with it.
///
/// Rendered on the brand fill rather than white: it is the one surface in the
/// app that should feel like a statement, and it anchors the colour identity
/// on an otherwise restrained screen. White ink on `#2563EB` measures 5.17:1,
/// so the figure stays AA at every size used here.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.label,
    required this.balance,
    super.key,
    this.caption,
    this.trailing,
    this.onTap,
  });

  final String label;
  final Money balance;
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      onTap: onTap,
      background: colors.primary,
      borderColor: colors.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      semanticLabel:
          '$label: ${balance.semanticLabel}'
          '${caption == null ? '' : '. $caption'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    // 80% white on the brand blue still clears 3:1; the label
                    // is deliberately quieter than the figure.
                    color: colors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // colorBySign is off: on a blue fill, green or red ink would fail
          // contrast. Direction is carried by the caption instead.
          MoneyText(
            balance,
            size: MoneySize.hero,
            colorBySign: false,
            color: colors.onPrimary,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              caption!,
              style: AppTypography.bodySmall.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Which semantic a summary card represents.
enum FinanceKind { income, expense, savings, neutral }

/// A compact figure card: income, expenses or savings for a period.
///
/// Designed to sit two-across in a row on a phone, so the label wraps to two
/// lines rather than being truncated — a card reading "Total expens…" is not
/// acceptable on a screen about money.
class FinanceSummaryCard extends StatelessWidget {
  const FinanceSummaryCard({
    required this.label,
    required this.amount,
    required this.kind,
    super.key,
    this.caption,
    this.onTap,
  });

  const FinanceSummaryCard.income({
    required this.label,
    required this.amount,
    super.key,
    this.caption,
    this.onTap,
  }) : kind = FinanceKind.income;

  const FinanceSummaryCard.expense({
    required this.label,
    required this.amount,
    super.key,
    this.caption,
    this.onTap,
  }) : kind = FinanceKind.expense;

  const FinanceSummaryCard.savings({
    required this.label,
    required this.amount,
    super.key,
    this.caption,
    this.onTap,
  }) : kind = FinanceKind.savings;

  final String label;
  final Money amount;
  final FinanceKind kind;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final (Color tint, Color ink, IconData icon) = switch (kind) {
      FinanceKind.income => (
        finance.incomeSurface,
        finance.incomeText,
        AppIcons.income,
      ),
      FinanceKind.expense => (
        finance.expenseSurface,
        finance.expenseText,
        AppIcons.expense,
      ),
      FinanceKind.savings => (
        finance.savingsSurface,
        finance.savingsText,
        AppIcons.savings,
      ),
      FinanceKind.neutral => (
        finance.surfaceMuted,
        finance.textPrimary,
        AppIcons.balance,
      ),
    };

    return AppCard(
      onTap: onTap,
      semanticLabel:
          '$label: ${amount.semanticLabel}'
          '${caption == null ? '' : '. $caption'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                alignment: Alignment.center,
                // The icon sits on its own tint, where the mark colour has
                // enough contrast; the arrow direction repeats the meaning
                // so colour is not the only cue.
                child: Icon(icon, size: AppIconSize.sm, color: ink),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: finance.textSecondary,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MoneyText(
            amount,
            size: MoneySize.large,
            colorBySign: false,
            color: kind == FinanceKind.neutral ? finance.textPrimary : ink,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Budget vs actual for one category.
///
/// Shows spent, limit, a progress bar and a status line. The status is words
/// plus an icon plus colour — never colour alone — and the remaining amount is
/// spelled out rather than left for the user to subtract.
///
/// [spent], [limit] and [ratio] all arrive from the caller. This card does no
/// arithmetic on money: Rule 1 of the architecture keeps every financial
/// figure on the backend, and a client-side `spent / limit` is exactly the
/// kind of drift that rule exists to prevent.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    required this.category,
    required this.spent,
    required this.limit,
    required this.ratio,
    required this.remaining,
    super.key,
    this.onTap,
  });

  final String category;
  final Money spent;
  final Money limit;

  /// Share of the limit used, supplied by the backend.
  final double ratio;

  /// What is left, or what it is over by when [ratio] exceeds 1.
  final Money remaining;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final over = ratio > 1.0;
    final close = !over && ratio >= 0.8;

    final (StatusTone tone, String statusLabel) = over
        ? (StatusTone.error, 'Over budget')
        : close
        ? (StatusTone.warning, 'Close to limit')
        : (StatusTone.success, 'On track');

    return AppCard(
      onTap: onTap,
      semanticLabel:
          '$category budget. '
          '${spent.semanticLabel} spent of ${limit.semanticLabel}. '
          '${(ratio * 100).round()} percent used. '
          '$statusLabel. '
          '${remaining.semanticLabel} ${over ? 'over' : 'remaining'}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(category: category, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: AppTypography.titleCard.copyWith(
                        color: finance.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    StatusIndicator(
                      label: statusLabel,
                      tone: tone,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Flexible, not a bare Column: a Row lays its non-flex children
              // out first with unbounded width, so an unflexed amount column
              // takes everything it wants and leaves Expanded in deficit —
              // which overflowed by 58px on a 390dp screen. With a flex the
              // amounts share the row and ellipsise instead.
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      spent,
                      size: MoneySize.medium,
                      colorBySign: false,
                      alignment: Alignment.centerRight,
                    ),
                    Text(
                      'of ${limit.format()}',
                      style: AppTypography.caption.copyWith(
                        color: finance.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(value: ratio, semanticLabel: '$category budget used'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${(ratio * 100).round()}% used',
                  style: AppTypography.caption.copyWith(
                    color: finance.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  over
                      ? '${remaining.format()} over'
                      : '${remaining.format()} left',
                  style: AppTypography.caption.copyWith(
                    color: over ? finance.expenseText : finance.textSecondary,
                    fontWeight: AppTypography.medium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One transaction in a list.
///
/// A list row rather than a card: a feed of fifty bordered cards is heavy to
/// scroll and wastes horizontal space on a phone. Rows sit on a shared card
/// with dividers between them.
///
/// The layout is deliberately conventional — icon, description, meta, amount
/// right-aligned — because this is the screen a first-time user meets first
/// and it should look like every statement they have ever seen.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.description,
    required this.category,
    required this.amount,
    super.key,
    this.date,
    this.onTap,
    this.trailing,
  });

  final String description;
  final String category;
  final Money amount;

  /// Pre-formatted by the caller: date formatting is a localisation concern,
  /// not a component one.
  final String? date;

  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final meta = [category, ?date].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardAll,
      child: Semantics(
        label:
            '$description, $category'
            '${date == null ? '' : ', $date'}, ${amount.semanticLabel}',
        button: onTap != null,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              CategoryIcon(category: category),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: AppTypography.bodyLarge.copyWith(
                        color: finance.textPrimary,
                        fontWeight: AppTypography.medium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      meta,
                      style: AppTypography.bodySmall.copyWith(
                        color: finance.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Sign is shown as well as colour, so direction survives for a
              // colour-blind reader and in a grayscale screenshot.
              MoneyText(
                amount,
                size: MoneySize.medium,
                showSign: true,
                alignment: Alignment.centerRight,
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
