import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../budgets/presentation/providers/budget_providers.dart';
import '../../../reports/presentation/providers/report_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

import '../../data/mock_dashboard_repository.dart';
import '../../domain/dashboard_data.dart';
import '../../domain/dashboard_period.dart';
import '../../domain/dashboard_repository.dart';

/// Re-exported: the dashboard reads the clock, and callers that already
/// import this file should not need a second import to reach it.
export '../../../../core/time/clock.dart' show clockProvider;

/// Where the dashboard's figures come from.
///
/// Phase 04 binds this to the mock. Phase 05 onwards overrides it with an
/// API-backed repository and nothing above this line changes.
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => MockDashboardRepository(
    // Reads the report repository rather than authoring its own figures,
    // so the dashboard and the reports screen cannot disagree about the
    // same month.
    reports: ref.watch(reportRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

/// Whether the mock reports a populated account or an empty one.
///
/// Exists so the empty dashboard — a required state — is reachable without
/// editing code. Settings exposes the switch. Goes away with the mock.
class MockDataModeController extends Notifier<MockDataMode> {
  @override
  MockDataMode build() => MockDataMode.populated;

  void select(MockDataMode mode) => state = mode;

  void toggle() => state = state == MockDataMode.populated
      ? MockDataMode.empty
      : MockDataMode.populated;
}

final mockDataModeProvider =
    NotifierProvider<MockDataModeController, MockDataMode>(
      MockDataModeController.new,
    );

/// The window the dashboard is summarising.
class SelectedPeriodController extends Notifier<DashboardPeriod> {
  @override
  DashboardPeriod build() => const DashboardPeriod.thisMonth();

  void select(DashboardPeriod period) => state = period;
}

final selectedPeriodProvider =
    NotifierProvider<SelectedPeriodController, DashboardPeriod>(
      SelectedPeriodController.new,
    );

/// The dashboard's data for the selected period.
///
/// One provider for the whole screen rather than one per card: the real
/// endpoint is a single request, and six independent futures would give the
/// dashboard six ways to half-load and six spinners to reconcile.
///
/// `AsyncValue` carries loading and error without either being invented
/// here, which is what lets the screen render all three states from one
/// switch.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final mode = ref.watch(mockDataModeProvider);

  // Depends on the transaction list so recording something from the
  // dashboard's own quick action refreshes the figures behind it. Without
  // this the user adds an expense, lands back on the dashboard, and finds
  // the totals unchanged.
  ref.watch(transactionListProvider);

  // And on budgets, so setting or changing one moves the card that
  // reports it.
  ref.watch(budgetBoardProvider);

  final repository = ref.read(dashboardRepositoryProvider);

  // Only the mock has a mode. The real repository reports what is there.
  if (repository is MockDashboardRepository) repository.mode = mode;

  return repository.load(period);
});
