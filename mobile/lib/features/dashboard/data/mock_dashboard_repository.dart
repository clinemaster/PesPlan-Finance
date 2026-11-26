import '../../../core/money/money.dart';
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
/// Savings goals, and the budget limit. Neither feature exists yet — there
/// is nothing to read them from — so they stay placeholders until their
/// own phases. The budget's *spending* is real: it is the period's
/// expenses, so the budget card and the Money out card above it can never
/// disagree.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    required this.reports,
    required this.transactions,
    required this.now,
    this.mode = MockDataMode.populated,
    this.delay = const Duration(milliseconds: 250),
  });

  final ReportRepository reports;
  final TransactionRepository transactions;
  final DateTime Function() now;

  MockDataMode mode;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  /// A placeholder monthly limit, until budgets are a feature.
  static const int _monthlyBudgetMinorUnits = 2200000;

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
      budget: _budgetFor(period, report.expenses),
      savings: _savings,
      recentTransactions: await _recent(),
    );
  }

  /// Dashboard windows and report windows are the same windows.
  ReportPeriod _asReportPeriod(DashboardPeriod period) =>
      switch (period.kind) {
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

    final rows = [
      for (final group in view.groups) ...group.transactions,
    ].take(5);

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
  /// would be comparing a year's spending with a month's limit — which is
  /// what the authored version used to do, scaled, and it was never
  /// honest. For other windows the section invites the user to set one.
  BudgetOverview? _budgetFor(DashboardPeriod period, Money expenses) {
    if (period.kind != PeriodKind.thisMonth) return null;

    const limit = _monthlyBudgetMinorUnits;
    final spent = expenses.minorUnits;
    final remaining = limit - spent;
    final ratio = spent / limit;

    return BudgetOverview(
      limit: const Money(limit),
      spent: expenses,
      remaining: Money(remaining),
      ratio: ratio,
      status: switch (ratio) {
        > 1.0 => BudgetStatus.overBudget,
        >= 0.8 => BudgetStatus.closeToLimit,
        _ => BudgetStatus.comfortable,
      },
      categoryCount: 6,
    );
  }

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
