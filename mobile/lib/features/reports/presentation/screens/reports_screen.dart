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

/// Reports and analytics.
///
/// One screen covers day, week, month, year and a custom range, because
/// the question is the same in every case — what came in, what went out,
/// where did it go — and only the window changes. Five screens would be
/// five places to fix the same wording.
///
/// The annual report and the year comparison are separate, because both
/// ask a different question and carry controls this screen does not need.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final controller = ref.read(reportPeriodProvider.notifier);
    final report = ref.watch(reportProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppTopBar(
        title: 'Reports',
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
              child: Column(
                children: [
                  ReportKindSelector(
                    selected: period.kind,
                    onSelected: (kind) => kind == ReportPeriodKind.custom
                        ? _pickRange(context, ref, period)
                        : controller.setKind(kind),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PeriodStepper(
                    title: period.title(),
                    subtitle: period.kind == ReportPeriodKind.custom
                        ? '${period.dayCount} days'
                        : null,
                    onPrevious: period.kind == ReportPeriodKind.custom
                        ? null
                        : controller.previous,
                    onNext:
                        period.kind != ReportPeriodKind.custom &&
                            period.canGoNext(now)
                        ? controller.next
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (report) {
                AsyncData(:final value) when value.isEmpty => _EmptyReport(
                  period: period,
                ),
                AsyncData(:final value) => _Report(data: value, period: period),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not build that report. $error',
                  onRetry: () => ref.invalidate(reportProvider),
                ),
                _ => const _LoadingReport(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod current,
  ) async {
    final now = ref.read(clockProvider)();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      // The picker itself refuses a future end date and a start after an
      // end, which is why validateCustomRange exists mainly for the
      // cases the picker cannot police — a range handed in from a link,
      // or a future device clock.
      lastDate: now,
      initialDateRange: current.kind == ReportPeriodKind.custom
          ? DateTimeRange(start: current.start, end: current.end)
          : null,
      helpText: 'Report period',
    );
    if (picked == null || !context.mounted) return;

    final error = validateCustomRange(
      start: picked.start,
      end: picked.end,
      now: now,
    );
    if (error != null) {
      AppSnackbar.error(context, error.message);
      return;
    }

    ref
        .read(reportPeriodProvider.notifier)
        .select(ReportPeriod.custom(from: picked.start, to: picked.end));
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.data, required this.period});

  final ReportData data;
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
                '${period.title()} is still running, so these figures '
                'cover it only up to today.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        ReportSummaryCard(data: data),
        const SizedBox(height: AppSpacing.cardGap),
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: AppSpacing.sectionGap),

        // Describes the buckets rather than repeating the period, which
        // the stepper directly above already states.
        ReportTrendCard(points: data.points, subtitle: _bucketLabel(period)),
        const SizedBox(height: AppSpacing.sectionGap),

        SectionHeader(
          title: 'Where it went',
          subtitle: 'Tap a category to see the transactions behind it',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        CategoryBreakdownCard(
          categories: data.categories,
          onCategoryTap: (slice) => _openCategory(context, ref, slice),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        AppButton.outlined(
          label: 'Annual report',
          icon: AppIcons.calendar,
          onPressed: () => context.push(Routes.reportsAnnual),
        ),
      ],
    );
  }

  static String _bucketLabel(ReportPeriod period) => switch (period.kind) {
    ReportPeriodKind.today => 'the day',
    ReportPeriodKind.week => 'day by day',
    ReportPeriodKind.month => 'week by week',
    ReportPeriodKind.year => 'month by month',
    ReportPeriodKind.custom => 'across the range',
  };

  /// Drill-down, done by handing the question to the screen that already
  /// answers it.
  ///
  /// The transactions list can filter by category and date range, so
  /// "show me the Food in November" is that filter applied and the user
  /// moved there — not a second list inside reports that would have to
  /// grow its own search, grouping and detail sheet.
  void _openCategory(
    BuildContext context,
    WidgetRef ref,
    CategorySlice slice,
  ) {
    ref
        .read(transactionFilterProvider.notifier)
        .setCategories({slice.categoryId});
    ref
        .read(transactionFilterProvider.notifier)
        .setDateRange(from: period.start, to: period.end);

    context.go(Routes.transactions);
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: EmptyState(
          icon: AppIcons.insights,
          title: 'Nothing in ${period.title()}',
          // Distinct from "you have no records at all": the user can step
          // to another period and find something, so the way out is the
          // stepper above rather than adding a transaction.
          message:
              'No transactions were recorded in this period. Step back to '
              'an earlier one, or pick a wider window.',
        ),
      ),
    );
  }
}

class _LoadingReport extends StatelessWidget {
  const _LoadingReport();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(height: 168, radius: AppRadius.card),
          SizedBox(height: AppSpacing.cardGap),
          Row(
            children: [
              Expanded(child: Skeleton(height: 84, radius: AppRadius.card)),
              SizedBox(width: AppSpacing.cardGap),
              Expanded(child: Skeleton(height: 84, radius: AppRadius.card)),
            ],
          ),
          SizedBox(height: AppSpacing.sectionGap),
          Skeleton(height: 240, radius: AppRadius.card),
        ],
      ),
    );
  }
}
