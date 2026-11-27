import '../../../core/money/money.dart';
import '../../budgets/domain/budget_repository.dart';
import '../../budgets/domain/budget_status.dart' as plans;
import '../../reports/domain/report_period.dart';
import '../../reports/domain/report_repository.dart';
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
/// ## What is still authored, and why
///
/// Only the savings goals. There is no savings feature to read them from
/// yet, so they stay a placeholder until that phase. The budget card
/// reads the budgets feature, so the limit it quotes is the one the user
/// actually set and the spending against it is the period's own
/// expenses — the card, the Money out figure above it and the Budgets
/// screen cannot disagree.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    required this.reports,
    required this.transactions,
    required this.budgets,
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
      savings: _savings,
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

  /// Still authored: there is no savings feature to read from yet.
  ///
  /// Three goals, two previewed. The third has nothing saved, which is why
  /// the previews do not add up to the headline — a real account looks
  /// like that, and a preview that always reconciles hides that it is one.
  static const SavingsOverview _savings = SavingsOverview(
    activeGoals: 3,
    totalSaved: Money(750000),
    totalTarget: Money(3200000),
    ratio: 0.23,
    previews: [
      GoalPreview(
        name: 'Emergency fund',
        saved: Money(450000),
        target: Money(1000000),
        ratio: 0.45,
        caption: 'Started in June',
      ),
      GoalPreview(
        name: 'New laptop',
        saved: Money(300000),
        target: Money(1500000),
        ratio: 0.20,
        caption: 'Target: March 2027',
      ),
    ],
  );
}
