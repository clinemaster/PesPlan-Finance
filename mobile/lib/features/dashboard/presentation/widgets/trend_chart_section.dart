import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/dashboard_data.dart';
import '../../domain/dashboard_period.dart';

/// Income against spending, over the selected period.
///
/// ## Why the form changes with the period
///
/// Twelve months of grouped bars on a phone gives twenty-four bars about
/// seven pixels wide — present, but not readable, which is the same as not
/// there. A line carries a year comfortably and shows the shape of the
/// trend, which is the question a year view is asked.
///
/// Four weeks is the opposite case: too few points for a line to describe
/// anything, and bars make the single payday obvious at a glance.
///
/// Both sit on one shared axis. There is deliberately no second y-axis —
/// two scales on one plot invent a correlation that is not in the data.
class TrendChartSection extends StatelessWidget {
  const TrendChartSection({
    required this.data,
    required this.period,
    super.key,
  });

  final DashboardData data;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final trend = data.trend;

    if (trend.isEmpty) return const SizedBox.shrink();

    final incomeSeries = ChartSeries(
      name: 'Income',
      color: finance.income,
      points: [
        for (var i = 0; i < trend.labels.length; i++)
          ChartPoint(label: trend.labels[i], value: trend.income[i]),
      ],
    );

    final expenseSeries = ChartSeries(
      name: 'Spending',
      color: finance.expense,
      points: [
        for (var i = 0; i < trend.labels.length; i++)
          ChartPoint(label: trend.labels[i], value: trend.expenses[i]),
      ],
    );

    final series = [incomeSeries, expenseSeries];
    final useLine = period.kind == PeriodKind.thisYear;

    return ChartContainer(
      title: 'Income and spending',
      subtitle: period.describe(),
      height: 220,
      semanticLabel:
          'Income and spending for ${period.describe()}. '
          'Income ${data.income.semanticLabel}, '
          'spending ${data.expenses.semanticLabel}.',
      legend: Row(
        children: [
          ChartLegendItem(
            color: finance.income,
            label: 'Income',
            isLine: useLine,
          ),
          const SizedBox(width: AppSpacing.lg),
          ChartLegendItem(
            color: finance.expense,
            label: 'Spending',
            isLine: useLine,
          ),
        ],
      ),
      chart: useLine
          ? AppLineChart(series: series, showArea: false)
          : AppBarChart(series: series),
      // The chart's own numbers, for anyone who cannot read a chart — or
      // who simply wants the figure rather than the shape.
      table: _TrendTable(trend: trend),
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.trend});

  final TrendSeries trend;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    Widget cell(String text, {bool header = false, Alignment? align}) => Expanded(
      child: Align(
        alignment: align ?? Alignment.centerRight,
        child: Text(
          text,
          style:
              (header ? AppTypography.labelSmall : AppTypography.bodySmall)
                  .copyWith(
                    color: header ? finance.textSecondary : finance.textPrimary,
                  ),
        ),
      ),
    );

    String amount(int? value) =>
        value == null ? '—' : Money(value).format(showSymbol: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              cell('Period', header: true, align: Alignment.centerLeft),
              cell('In', header: true),
              cell('Out', header: true),
            ],
          ),
        ),
        const AppDivider(),
        for (var i = 0; i < trend.labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                cell(trend.labels[i], align: Alignment.centerLeft),
                cell(amount(trend.income[i])),
                cell(amount(trend.expenses[i])),
              ],
            ),
          ),
      ],
    );
  }
}
