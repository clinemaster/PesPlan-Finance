import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/transaction_view.dart';

/// In, out and net for whatever is currently listed.
///
/// One compact strip rather than three cards: on this screen the list is
/// the content and the summary is context, so it is sized to be glanced at
/// and scrolled past. The dashboard is where these figures get room.
///
/// It describes the *filtered* set, which is the point — narrowing to Food
/// and seeing what Food cost is most of the reason to filter at all. The
/// caption says so, because a total that silently changes meaning when a
/// chip is tapped would otherwise be misread.
class TransactionsSummaryStrip extends StatelessWidget {
  const TransactionsSummaryStrip({
    required this.totals,
    required this.isFiltered,
    super.key,
  });

  final TransactionTotals totals;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: 'In',
                  amount: totals.income,
                  color: finance.incomeText,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Out',
                  amount: totals.expenses,
                  color: finance.expenseText,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Net',
                  amount: totals.net,
                  color: finance.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isFiltered
                ? '${totals.count} matching · not your whole history'
                : '${totals.count} '
                      '${totals.count == 1 ? 'transaction' : 'transactions'}',
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final Money amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label: '$label ${amount.semanticLabel}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          MoneyText(
            amount,
            size: MoneySize.small,
            colorBySign: false,
            color: color,
            abbreviate: true,
          ),
        ],
      ),
    );
  }
}
