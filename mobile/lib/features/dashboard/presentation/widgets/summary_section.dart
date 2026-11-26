import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/dashboard_data.dart';
import '../../domain/dashboard_period.dart';

/// The three figures the dashboard exists to deliver.
///
/// ## Net movement is not a balance, and the wording has to carry that
///
/// This app has no account connection. It knows what the user recorded, so
/// it can state what moved; it cannot state what is in anyone's bank. A
/// hero figure labelled "Balance" would be a claim the product cannot
/// support, and the user would discover the gap the first time they checked
/// their bank app.
///
/// Hence "Net this month" plus an explicit caption. The caption is not
/// decoration — it is the part that keeps the headline honest, and it
/// should survive any future tidy-up of this card.
class SummarySection extends StatelessWidget {
  const SummarySection({required this.data, required this.period, super.key});

  final DashboardData data;
  final DashboardPeriod period;

  String get _netLabel => switch (period.kind) {
    PeriodKind.thisMonth => 'Net this month',
    PeriodKind.thisYear => 'Net this year',
    PeriodKind.custom => 'Net this period',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BalanceCard(
          label: _netLabel,
          balance: data.net,
          caption: 'Income minus expenses · not an account balance',
        ),
        const SizedBox(height: AppSpacing.cardGap),
        // IntrinsicHeight so the two cards match whichever is taller.
        // `stretch` alone cannot do it here: the Row sits in a scroll view,
        // where its height is unbounded, and stretching to infinity is not
        // a layout. The cost is one extra measuring pass over two cards.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FinanceSummaryCard.income(
                  label: 'Money in',
                  amount: data.income,
                  caption: period.describe(),
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: FinanceSummaryCard.expense(
                  label: 'Money out',
                  amount: data.expenses,
                  caption: period.describe(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
