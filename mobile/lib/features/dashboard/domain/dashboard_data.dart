import '../../../core/money/money.dart';

/// Everything one dashboard render needs, for one period.
///
/// ## Why every figure here is already computed
///
/// Architecture Rule 1: the Flutter app is a presentation client with no
/// financial engine. Dart may format and lay out; it may not sum, net,
/// derive a rate or decide a budget's state. So [net], [ratio], [remaining]
/// and every total below arrive as values, not as something a widget works
/// out from the parts.
///
/// That matters even while the data is mocked. If the UI computed its own
/// net today, Phase 05 would wire a backend into a client that quietly
/// disagrees with it — and the six reporting rules the Python layer encodes
/// (transfers excluded, expenses as positive magnitudes, null months) would
/// have to be reimplemented in Dart and kept in step forever. Keeping the
/// arithmetic on the far side of this class is what stops that.
class DashboardData {
  const DashboardData({
    required this.income,
    required this.expenses,
    required this.net,
    required this.trend,
    required this.budget,
    required this.savings,
    required this.recentTransactions,
  });

  /// An account with nothing recorded yet.
  ///
  /// Deliberately not "zeroes everywhere": the dashboard renders a welcome
  /// instead, because showing TSh 0 across five cards states a financial
  /// fact the app has no basis for.
  const DashboardData.empty()
    : income = const Money(0),
      expenses = const Money(0),
      net = const Money(0),
      trend = const TrendSeries(labels: [], income: [], expenses: []),
      budget = null,
      savings = null,
      recentTransactions = const [];

  /// Money in over the period.
  final Money income;

  /// Money out, as a positive magnitude — matching the reporting contract,
  /// where `expense_cents` is positive while stored amounts are negative.
  final Money expenses;

  /// Income minus expenses, **computed by the backend**.
  ///
  /// This is a movement, not a balance. The UI must never present it as
  /// available cash: the app has no account connection, so it cannot know
  /// what is in anyone's bank.
  final Money net;

  final TrendSeries trend;

  /// Null when no budget is set for the period.
  final BudgetOverview? budget;

  /// Null when the user has no savings goals.
  final SavingsOverview? savings;

  final List<TransactionSummary> recentTransactions;

  /// True when there is nothing recorded to summarise.
  bool get isEmpty =>
      recentTransactions.isEmpty &&
      income.isZero &&
      expenses.isZero &&
      budget == null &&
      savings == null;
}

/// Income and spending over time, on one shared axis.
///
/// A `null` entry is a month with no records — not a month of zero. The
/// charts render it as a break, which is the only honest reading.
class TrendSeries {
  const TrendSeries({
    required this.labels,
    required this.income,
    required this.expenses,
  });

  final List<String> labels;
  final List<int?> income;
  final List<int?> expenses;

  bool get isEmpty => labels.isEmpty;
}

/// The budget headline, as the backend evaluates it.
class BudgetOverview {
  const BudgetOverview({
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.ratio,
    required this.status,
    required this.categoryCount,
  });

  final Money limit;
  final Money spent;

  /// What is left. Negative when the limit is exceeded.
  final Money remaining;

  /// Spent as a share of the limit. Above 1.0 means over budget.
  final double ratio;

  final BudgetStatus status;

  /// How many category budgets roll up into this figure.
  final int categoryCount;
}

enum BudgetStatus {
  comfortable,
  closeToLimit,
  overBudget;

  String get label => switch (this) {
    BudgetStatus.comfortable => 'On track',
    BudgetStatus.closeToLimit => 'Close to limit',
    BudgetStatus.overBudget => 'Over budget',
  };
}

/// The savings headline plus a couple of goals worth showing.
class SavingsOverview {
  const SavingsOverview({
    required this.activeGoals,
    required this.totalSaved,
    required this.totalTarget,
    required this.ratio,
    required this.previews,
  });

  final int activeGoals;
  final Money totalSaved;
  final Money totalTarget;

  /// Saved as a share of target, across all goals.
  final double ratio;

  /// The one or two goals shown on the dashboard. The rest live in Goals.
  final List<GoalPreview> previews;
}

class GoalPreview {
  const GoalPreview({
    required this.name,
    required this.saved,
    required this.target,
    required this.ratio,
    required this.caption,
  });

  final String name;
  final Money saved;
  final Money target;
  final double ratio;

  /// Context the number cannot carry on its own, e.g. "4 months to go".
  final String caption;
}

/// One row in the recent activity list.
class TransactionSummary {
  const TransactionSummary({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
  });

  final String id;
  final String description;

  /// Lowercase category key, resolved to an icon by `AppIcons.forCategory`.
  final String category;

  /// Signed: negative is money out. The sign is the income/expense
  /// indicator, and `MoneyText` colours it accordingly.
  final Money amount;

  /// Pre-formatted for display ("Today", "23 Nov"). Formatting a date needs
  /// a locale and a notion of today, both of which belong outside a widget.
  final String date;

  bool get isIncome => !amount.isNegative && !amount.isZero;
}
