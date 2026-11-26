import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/dashboard_data.dart';

/// The last five things that happened.
///
/// Five because it is enough to recognise the account as yours and spot
/// something wrong, and few enough that the dashboard does not become the
/// transaction list. The sign on each amount is the income/expense
/// indicator — `MoneyText` colours it, so the row needs no extra badge
/// saying what the colour already says.
class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({required this.transactions, super.key});

  final List<TransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.transactions),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (transactions.isEmpty)
          AppCard(
            child: Text(
              'Nothing recorded yet.',
              style: AppTypography.bodyMedium.copyWith(
                color: finance.textSecondary,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final transaction in transactions) ...[
                  TransactionTile(
                    description: transaction.description,
                    category: transaction.category,
                    amount: transaction.amount,
                    date: transaction.date,
                    onTap: () => context.go(Routes.transactions),
                  ),
                  if (transaction != transactions.last) const AppDivider(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
