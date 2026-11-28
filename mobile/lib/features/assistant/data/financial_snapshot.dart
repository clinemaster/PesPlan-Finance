import '../../budgets/domain/budget_progress.dart';
import '../../budgets/domain/budget_repository.dart';
import '../../reports/domain/report_data.dart';
import '../../reports/domain/report_period.dart';
import '../../reports/domain/report_repository.dart';
import '../../savings/domain/goal_progress.dart';
import '../../savings/domain/savings_repository.dart';

/// Everything the assistant is allowed to know.
///
/// ## The assistant reads the app, not a script
///
/// Every figure here comes from the repository that owns it — reports
/// for spending and income, budgets for limits, savings for goals. The
/// answers are therefore the same numbers the user can go and check on
/// the other screens, which is the only version of this feature worth
/// shipping: an assistant that quotes 420,000 while Reports says
/// 1,073,900 is worse than no assistant.
///
/// It is also the whole of what the assistant can see. There is no
/// profile, no location, no device data, nothing from outside the app —
/// which is what lets the privacy note say so plainly.
class FinancialSnapshot {
  const FinancialSnapshot({
    required this.today,
    required this.thisMonth,
    required this.lastMonth,
    required this.thisYear,
    required this.lastYear,
    required this.budgets,
    required this.savings,
  });

  final DateTime today;

  final ReportData thisMonth;
  final ReportData lastMonth;
  final ReportData thisYear;
  final ReportData lastYear;

  final BudgetBoard budgets;
  final SavingsBoard savings;

  /// Nothing recorded at all — no transactions, no budgets, no goals.
  ///
  /// Checked across all three rather than transactions alone: someone
  /// who has set a savings goal and recorded nothing else still has a
  /// question worth answering about that goal.
  bool get hasNothing =>
      thisYear.transactionCount == 0 &&
      lastYear.transactionCount == 0 &&
      budgets.isEmpty &&
      savings.isEmpty;

  bool get hasThisMonth => thisMonth.transactionCount > 0;

  CategorySlice? get topCategory =>
      thisMonth.categories.isEmpty ? null : thisMonth.categories.first;

  /// Gathers a snapshot from the repositories that own each figure.
  static Future<FinancialSnapshot> gather({
    required DateTime now,
    required ReportRepository reports,
    required BudgetRepository budgets,
    required SavingsRepository savings,
  }) async {
    final lastMonthDate = DateTime(now.year, now.month - 1);

    final results = await Future.wait([
      reports.report(ReportPeriod.month(now)),
      reports.report(
        ReportPeriod.monthOf(lastMonthDate.year, lastMonthDate.month),
      ),
      reports.report(ReportPeriod.year(now)),
      reports.report(ReportPeriod.yearOf(now.year - 1)),
    ]);

    return FinancialSnapshot(
      today: now,
      thisMonth: results[0],
      lastMonth: results[1],
      thisYear: results[2],
      lastYear: results[3],
      budgets: await budgets.board(year: now.year, month: now.month),
      savings: await savings.board(),
    );
  }
}
