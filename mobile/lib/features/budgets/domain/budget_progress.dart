import '../../../core/money/money.dart';
import 'budget.dart';
import 'budget_status.dart';

/// A budget paired with what was actually spent against it.
///
/// ## Every figure here arrives computed
///
/// Architecture Rule 1: the app has no financial engine. [spent],
/// [remaining] and [ratio] are produced by the repository from recorded
/// transactions; nothing here or above it derives them.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.ratio,
    required this.overspend,
    required this.status,
    required this.transactionCount,
  });

  final Budget budget;

  /// Spent against this budget, as a positive magnitude.
  final Money spent;

  /// What is left. Negative once the limit is passed — the sign is the
  /// point, and the UI reads it rather than recomputing it.
  final Money remaining;

  /// Spent over budgeted. Above 1.0 means over.
  final double ratio;

  /// How far past the limit, as a positive magnitude. Zero when within.
  ///
  /// Supplied rather than derived from [remaining], because negating a
  /// stored amount is still arithmetic on money and the domain does not
  /// do that — `test/transactions/architecture_test.dart` caught exactly
  /// this when it was a getter here.
  final Money overspend;

  final BudgetStatus status;

  /// How many transactions make up [spent]. Gives the detail sheet
  /// something to say beyond a number, and tells a user whether one big
  /// purchase or forty small ones did it.
  final int transactionCount;

  /// Whole percent, for display.
  int get percent => (ratio * 100).round();

  bool get isOver => remaining.isNegative;
}

/// One month of budgets, as the screen renders it.
class BudgetBoard {
  const BudgetBoard({
    required this.overall,
    required this.categories,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.unbudgetedSpending,
  });

  static const BudgetBoard empty = BudgetBoard(
    overall: null,
    categories: [],
    totalBudgeted: Money(0),
    totalSpent: Money(0),
    unbudgetedSpending: Money(0),
  );

  /// The month's overall budget, if one is set.
  final BudgetProgress? overall;

  /// Category budgets, the ones needing attention first.
  final List<BudgetProgress> categories;

  /// Everything budgeted across the category budgets.
  ///
  /// Not the same as the overall budget: a user can budget 300,000 across
  /// three categories while their overall limit is 800,000, and both
  /// numbers are true.
  final Money totalBudgeted;

  /// Spending across the month, whether budgeted or not.
  final Money totalSpent;

  /// Spending in categories with no budget.
  ///
  /// Shown because a category list that adds up to less than the month's
  /// spending looks broken otherwise, and because unbudgeted spending is
  /// the thing a user most often did not realise was happening.
  final Money unbudgetedSpending;

  bool get isEmpty => overall == null && categories.isEmpty;

  bool get hasUnbudgetedSpending => unbudgetedSpending.minorUnits > 0;
}
