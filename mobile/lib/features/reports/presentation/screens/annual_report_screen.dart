import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/report_data.dart';
import '../../domain/report_period.dart';
import '../providers/report_providers.dart';
import '../widgets/report_trend_card.dart';
import '../widgets/report_widgets.dart';

/// A year, January to December.
///
/// Separate from the general reports screen because a year asks different
/// questions — which month cost the most, what does an average month look
/// like, how did it compare with last year — and because its twelve
/// buckets are the one view worth drilling into month by month.
class AnnualReportScreen extends ConsumerStatefulWidget {
  const AnnualReportScreen({super.key, this.initialYear});

  final int? initialYear;

  @override
  ConsumerState<AnnualReportScreen> createState() =>
      _AnnualReportScreenState();
}

class _AnnualReportScreenState extends ConsumerState<AnnualReportScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? ref.read(clockProvider)().year;
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final period = ReportPeriod.yearOf(_year);
    final report = ref.watch(reportForProvider(period));

    return Scaffold(
      appBar: AppTopBar(
        title: 'Annual report',
        showBack: true,
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: AppIcons.insights,
            tooltip: 'Compare years',
            onPressed: () => context.push(Routes.reportsCompare),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                0,
              ),
              child: PeriodStepper(
                title: '$_year',
                subtitle: period.isInProgress(now) ? 'still running' : null,
                onPrevious: () => setState(() => _year--),
                onNext: _year < now.year
                    ? () => setState(() => _year++)
                    : null,
              ),
            ),
            Expanded(
              child: switch (report) {
                AsyncData(:final value) when value.isEmpty => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    child: EmptyState(
                      icon: AppIcons.insights,
                      title: 'Nothing recorded in $_year',
                      message:
                          'Step back to a year with records, or add '
                          'transactions for this one.',
                    ),
                  ),
                ),
                AsyncData(:final value) => _Annual(
                  data: value,
                  year: _year,
                  period: period,
                ),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not build that report. $error',
                  onRetry: () => ref.invalidate(reportForProvider(period)),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(AppSpacing.screenH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Skeleton(height: 168, radius: AppRadius.card),
                      SizedBox(height: AppSpacing.cardGap),
                      Skeleton(height: 240, radius: AppRadius.card),
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Annual extends ConsumerWidget {
  const _Annual({
    required this.data,
    required this.year,
    required this.period,
  });

  final ReportData data;
  final int year;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      children: [
        if (data.isInProgress) ...[
          InProgressNote(
            message:
                '$year is still running. Averages here are over the months '
                'so far, not twelve.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        ReportSummaryCard(data: data),
        const SizedBox(height: AppSpacing.cardGap),
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: AppSpacing.sectionGap),

        ReportTrendCard(
          points: data.points,
          subtitle: '$year, by month',
          title: 'Month by month',
          // Drill-down lives on the table rather than the painted bars:
          // a table row is an ordinary button, reachable by a screen
          // reader and by a thumb, where hit-testing a CustomPaint is
          // neither.
          onPointTap: (point) {
            final month = point.monthOfYear;
            if (month == null) return;
            ref
                .read(reportPeriodProvider.notifier)
                .select(ReportPeriod.monthOf(year, month));
            context.push(Routes.reports);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Open the table to see each month, and tap one for its own '
          'report.',
          style: AppTypography.caption.copyWith(
            color: context.finance.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        SectionHeader(
          title: 'Where it went in $year',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        CategoryBreakdownCard(
          categories: data.categories,
          onCategoryTap: (slice) {
            ref
                .read(transactionFilterProvider.notifier)
                .setCategories({slice.categoryId});
            ref
                .read(transactionFilterProvider.notifier)
                .setDateRange(from: period.start, to: period.end);
            context.go(Routes.transactions);
          },
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        AppButton.outlined(
          label: 'Compare with another year',
          icon: AppIcons.insights,
          onPressed: () => context.push(Routes.reportsCompare),
        ),
      ],
    );
  }
}
