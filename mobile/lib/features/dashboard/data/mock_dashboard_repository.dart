import '../../budgets/domain/budget_repository.dart';
import '../../budgets/domain/budget_status.dart' as plans;
import '../../reports/domain/report_period.dart';
import '../../reports/domain/report_repository.dart';
import '../../savings/domain/goal_timing.dart';
import '../../savings/domain/savings_repository.dart';
import '../../transactions/domain/date_labels.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_period.dart';
import '../domain/dashboard_repository.dart';

/// Whether the mock has anything to report.
///
/// The empty dashboard is a required state and is unreachable while the
/// account has records. The Settings screen exposes the switch; it goes
/// away with the mock.
enum MockDataMode { populated, empty }

/// The dashboard, derived from the same records as everything else.
///
/// ## Why this reads the report repository
///
/// It used to return authored constants. That made the dashboard the only
/// screen in the app inventing its own figures, and once Phase 06 put a
/// Reports entry in the dashboard header the two sat one tap apart saying
/// different things about the same month — November read TSh 3,200,000 in
/// on one screen and TSh 1,965,000 on the other. A user cannot tell which
/// to believe, and neither can a reviewer.
///
/// So the totals and the trend come from [ReportRepository], which derives
/// them from recorded transactions, and the recent rows come from the
/// transaction repository directly. The dashboard is now a summary of the
/// same truth rather than a parallel one.
///
/// ## Nothing here is authored any more
///
/// Every card reads the feature that owns it: totals and the trend from
/// reports, recent rows from transactions, the budget from budgets and
/// the savings preview from savings. The dashboard is a summary of the
/// same truth rather than a parallel one, so a figure cannot differ
/// between it and the screen one tap away.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    required this.reports,
    required this.transactions,
    required this.budgets,
    required this.savings,
    required this.now,
    this.mode = MockDataMode.populated,
    this.delay = const Duration(milliseconds: 250),
  });

  final ReportRepository reports;
  final TransactionRepository transactions;

  /// Where the month's plan comes from. Reading it rather than carrying
  /// an authored limit is what keeps the dashboard's budget card and the
  /// Budgets screen from quoting different numbers.
  final BudgetRepository budgets;

  /// Where the goals come from. Reading them rather than carrying
  /// authored goals is what keeps the dashboard's preview and the Goals
  /// screen from quoting different totals.
  final SavingsRepository savings;
  final DateTime Function() now;

  MockDataMode mode;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  @override
  Future<DashboardData> load(DashboardPeriod period) async {
    await Future<void>.delayed(delay);

    if (mode == MockDataMode.empty) return const DashboardData.empty();

    final report = await reports.report(_asReportPeriod(period));
    if (report.isEmpty) return const DashboardData.empty();

    return DashboardData(
      income: report.income,
      expenses: report.expenses,
      net: report.net,
      trend: TrendSeries(
        labels: [for (final point in report.points) point.label],
        income: [for (final point in report.points) point.income],
        expenses: [for (final point in report.points) point.expenses],
      ),
      budget: await _budgetFor(period),
      savings: await _savingsPreview(),
      recentTransactions: await _recent(),
    );
  }

  /// Dashboard windows and report windows are the same windows.
  ReportPeriod _asReportPeriod(DashboardPeriod period) => switch (period.kind) {
    PeriodKind.thisMonth => ReportPeriod.month(now()),
    PeriodKind.thisYear => ReportPeriod.year(now()),
    PeriodKind.custom => ReportPeriod.custom(
      from: period.start ?? now(),
      to: period.end ?? now(),
    ),
  };

  /// The five most recent transactions, whatever the selected period.
  ///
  /// "Recent activity" means recent, not "recent within the window" — a
  /// user switching to the year view is not asking to see January again.
  Future<List<TransactionSummary>> _recent() async {
    final view = await transactions.list(TransactionFilter.none);
    final today = now();

    final rows = [for (final group in view.groups) ...group.transactions]
        .take(5);

    return [
      for (final row in rows)
        TransactionSummary(
          id: row.id,
          description: row.title,
          category: row.categoryLabel,
          amount: row.amount,
          date: DateLabels.rowLabel(row.date, today),
        ),
    ];
  }

  /// A budget, but only where a monthly limit means something.
  ///
  /// The card is titled "Monthly budget", so showing it against a year
  /// would be comparing a year's spending with a month's limit. For
  /// other windows the section invites the user to set one.
  Future<BudgetOverview?> _budgetFor(DashboardPeriod period) async {
    if (period.kind != PeriodKind.thisMonth) return null;

    final today = now();
    final board = await budgets.board(year: today.year, month: today.month);

    final overall = board.overall;
    if (overall == null) return null;

    return BudgetOverview(
      limit: overall.budget.amount,
      spent: overall.spent,
      remaining: overall.remaining,
      ratio: overall.ratio,
      status: _statusFor(overall.status),
      // The categories the user actually budgeted, not a fixed number.
      categoryCount: board.categories.length,
    );
  }

  /// The budgets feature keeps four levels; the dashboard card shows
  /// three. "Approaching" folds into "close to limit" rather than into
  /// "on track": on a card the user only glances at, the earlier warning
  /// is the more useful of the two.
  BudgetStatus _statusFor(plans.BudgetStatus status) => switch (status) {
    plans.BudgetStatus.over => BudgetStatus.overBudget,
    plans.BudgetStatus.nearLimit ||
    plans.BudgetStatus.approaching => BudgetStatus.closeToLimit,
    plans.BudgetStatus.onTrack => BudgetStatus.comfortable,
  };

  /// The savings card: everything set aside, and the two goals closest
  /// to done.
  ///
  /// Not scoped to the selected period, and deliberately so. Savings are
  /// a balance, not a movement — "how much have I put aside this month"
  /// is a different question from the one this card answers, and
  /// shrinking the figure when someone switches to a shorter window
  /// would read as money disappearing.
  Future<SavingsOverview?> _savingsPreview() async {
    final board = await savings.board();

    // No goals is not zero goals worth of progress: the section renders
    // an invitation instead of a bar at 0%.
    if (board.active.isEmpty) return null;

    final today = now();

    return SavingsOverview(
      activeGoals: board.activeCount,
      totalSaved: board.totalSaved,
      totalTarget: board.totalTarget,
      ratio: board.ratio,
      previews: [
        for (final progress in board.active.take(2))
          GoalPreview(
            name: progress.goal.name,
            saved: progress.saved,
            target: progress.goal.target,
            ratio: progress.ratio,
            caption: GoalTiming.caption(
              progress.goal.targetDate,
              progress.goal.createdAt,
              today,
            ),
          ),
      ],
    );
  }
}
