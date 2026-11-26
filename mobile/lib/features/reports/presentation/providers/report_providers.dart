import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/mock_report_repository.dart';
import '../../domain/report_data.dart';
import '../../domain/report_period.dart';
import '../../domain/report_repository.dart';

/// Where reports come from.
///
/// Built on the transaction repository rather than beside it, so the
/// reports and the transaction list can never disagree about what was
/// recorded. Phase 13 overrides this with an API-backed implementation.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => MockReportRepository(
    transactions: ref.watch(transactionRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

/// The window the report screen is showing.
class ReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.month(ref.watch(clockProvider)());

  void select(ReportPeriod period) => state = period;

  void setKind(ReportPeriodKind kind) {
    final now = ref.read(clockProvider)();
    state = switch (kind) {
      ReportPeriodKind.today => ReportPeriod.today(now),
      ReportPeriodKind.week => ReportPeriod.week(now),
      ReportPeriodKind.month => ReportPeriod.month(now),
      ReportPeriodKind.year => ReportPeriod.year(now),
      // Custom needs dates the user has not chosen yet, so the caller
      // opens the picker and calls select() with the result.
      ReportPeriodKind.custom => state,
    };
  }

  void previous() => state = state.previous();

  /// Refuses to step into a window that has not started. A screen that
  /// lets someone walk into 2031 and find nothing looks broken, not empty.
  void next() {
    if (!state.canGoNext(ref.read(clockProvider)())) return;
    state = state.next();
  }
}

final reportPeriodProvider =
    NotifierProvider<ReportPeriodController, ReportPeriod>(
      ReportPeriodController.new,
    );

/// The report for the selected window.
final reportProvider = FutureProvider<ReportData>((ref) async {
  final period = ref.watch(reportPeriodProvider);

  // Depends on the transaction list so recording or editing something
  // refreshes the report rather than leaving a stale total on screen.
  ref.watch(transactionListProvider);

  return ref.read(reportRepositoryProvider).report(period);
});

/// A report for one specific window, independent of the screen's
/// selection. Used by the annual report, which owns its own year.
final reportForProvider = FutureProvider.family<ReportData, ReportPeriod>((
  ref,
  period,
) async {
  ref.watch(transactionListProvider);
  return ref.read(reportRepositoryProvider).report(period);
});

/// Years that actually hold records, newest first.
final yearsWithDataProvider = FutureProvider<List<int>>((ref) async {
  ref.watch(transactionListProvider);
  return ref.read(reportRepositoryProvider).yearsWithData();
});

/// Which two years the comparison screen is showing.
///
/// Null until the years are known — the screen picks the two most recent
/// with data, which is the comparison almost everyone wants.
class ComparisonYears {
  const ComparisonYears(this.earlier, this.later);

  final int earlier;
  final int later;

  @override
  bool operator ==(Object other) =>
      other is ComparisonYears &&
      other.earlier == earlier &&
      other.later == later;

  @override
  int get hashCode => Object.hash(earlier, later);
}

class ComparisonYearsController extends Notifier<ComparisonYears?> {
  @override
  ComparisonYears? build() => null;

  void select(ComparisonYears years) => state = years;

  void setEarlier(int year) => state = state == null
      ? ComparisonYears(year, year)
      : ComparisonYears(year, state!.later);

  void setLater(int year) => state = state == null
      ? ComparisonYears(year, year)
      : ComparisonYears(state!.earlier, year);
}

final comparisonYearsProvider =
    NotifierProvider<ComparisonYearsController, ComparisonYears?>(
      ComparisonYearsController.new,
    );

final yearComparisonProvider =
    FutureProvider.family<YearComparison, ComparisonYears>((ref, years) async {
      ref.watch(transactionListProvider);
      return ref
          .read(reportRepositoryProvider)
          .compareYears(years.earlier, years.later);
    });
