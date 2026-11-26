import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/report_data.dart';

/// Income against spending over the window.
///
/// ## No charting package
///
/// The design system already ships hand-painted line, bar and donut
/// charts built for exactly this palette and these mark rules — 24px bar
/// caps, breaks at missing data, no second y-axis. Adding fl_chart or
/// syncfusion would mean a second visual language for the same job, a
/// dependency to keep current, and library defaults quietly overriding
/// the token set. So this composes what is there.
///
/// Bars for a handful of buckets, a line for twelve: twenty-four grouped
/// bars on a phone are present but not readable, and a line of six points
/// has no shape to show.
class ReportTrendCard extends StatelessWidget {
  const ReportTrendCard({
    required this.points,
    required this.subtitle,
    super.key,
    this.onPointTap,
    this.title = 'Income and spending',
  });

  final List<ReportPoint> points;
  final String subtitle;
  final String title;

  /// Tapping a bucket. Used by the annual report to open a month.
  final void Function(ReportPoint point)? onPointTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    if (points.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleCard.copyWith(
                color: finance.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // A single day has a figure, not a trend. Saying so beats
              // drawing one bar and letting the user infer a shape.
              'A single day has no trend to show. Pick a week or longer.',
              style: AppTypography.bodySmall.copyWith(
                color: finance.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (points.every((point) => point.isEmpty)) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleCard.copyWith(
                color: finance.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nothing recorded in this period.',
              style: AppTypography.bodySmall.copyWith(
                color: finance.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final useLine = points.length > 8;

    final series = [
      ChartSeries(
        name: 'Income',
        color: finance.income,
        points: [
          for (final point in points)
            ChartPoint(label: point.label, value: point.income),
        ],
      ),
      ChartSeries(
        name: 'Spending',
        color: finance.expense,
        points: [
          for (final point in points)
            ChartPoint(label: point.label, value: point.expenses),
        ],
      ),
    ];

    return ChartContainer(
      title: title,
      subtitle: subtitle,
      height: 220,
      semanticLabel: 'Income and spending across $subtitle.',
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
      table: _TrendTable(points: points, onPointTap: onPointTap),
    );
  }
}

/// The chart's own numbers.
///
/// Doubles as the drill-down surface on the annual report: tapping a
/// painted bar means hit-testing a CustomPaint, where tapping a table row
/// is an ordinary button that a screen reader can reach too.
class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points, required this.onPointTap});

  final List<ReportPoint> points;
  final void Function(ReportPoint point)? onPointTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    Widget cell(String text, {bool header = false, Alignment? align}) =>
        Expanded(
          child: Align(
            alignment: align ?? Alignment.centerRight,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (header
                          ? AppTypography.labelSmall
                          : AppTypography.bodySmall)
                      .copyWith(
                        color: header
                            ? finance.textSecondary
                            : finance.textPrimary,
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
        for (final point in points)
          InkWell(
            onTap: onPointTap == null || point.isEmpty
                ? null
                : () => onPointTap!(point),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  cell(point.label, align: Alignment.centerLeft),
                  cell(amount(point.income)),
                  cell(amount(point.expenses)),
                  if (onPointTap != null)
                    SizedBox(
                      width: AppIconSize.md,
                      child: point.isEmpty
                          ? null
                          : Icon(
                              AppIcons.chevronRight,
                              size: AppIconSize.sm,
                              color: finance.textTertiary,
                            ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
