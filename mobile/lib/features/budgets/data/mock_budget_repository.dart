import '../../../core/money/money.dart';
import '../../reports/domain/report_data.dart';
import '../../reports/domain/report_period.dart';
import '../../reports/domain/report_repository.dart';
import '../domain/budget.dart';
import '../domain/budget_progress.dart';
import '../domain/budget_repository.dart';
import '../domain/budget_status.dart';
import 'budget_store.dart';

/// Budgets, measured against what was actually spent.
///
/// ## Spending comes from recorded transactions, not from a second set of
/// figures
///
/// A budget screen saying Food cost 50,000 while Reports says 106,900 for
/// the same month is the inconsistency this codebase has spent two
/// commits removing. So the spending side is read from
/// [ReportRepository], which reads the transaction repository — the same
/// records the list, the dashboard and the reports all show.
///
/// That is still mock data: the transactions behind it are generated and
/// local, and no server is involved. What it is not is a *parallel* set
/// of mock figures, which is what would make the screens disagree.
///
/// ## The third file allowed to add up money
///
/// Architecture Rule 1 keeps financial arithmetic out of the app. This
/// class plays the server while the data is mocked, so remaining and
/// ratio are worked out here and arrive above [BudgetRepository] already
/// computed. `test/transactions/architecture_test.dart` fails the build
/// if any of it leaks upward.
class MockBudgetRepository implements BudgetRepository {
  MockBudgetRepository({
    required this.reports,
    required this.now,
    this.thresholds = BudgetThresholds.standard,
    List<Budget>? seed,
    this.store,
    this.delay = const Duration(milliseconds: 250),
  }) : _budgets = _initial(now: now, seed: seed, store: store);

  final ReportRepository reports;
  final DateTime Function() now;

  /// Where a level begins. Injected so the thresholds are one decision,
  /// changeable in one place.
  final BudgetThresholds thresholds;

  final BudgetStore? store;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  final List<Budget> _budgets;

  int _nextId = 0;

  /// Everything held. For tests, and for the duplicate check.
  List<Budget> get all => List.unmodifiable(_budgets);

  static List<Budget> _initial({
    required DateTime Function() now,
    required List<Budget>? seed,
    required BudgetStore? store,
  }) {
    if (seed != null) return [...seed];
    if (store != null && store.hasStoredData) return store.read();

    final generated = _seedFor(now());
    store?.write(generated);
    return generated;
  }

  // ------------------------------------------------------------- reading

  @override
  Future<BudgetBoard> board({required int year, required int month}) async {
    await Future<void>.delayed(delay);

    final budgets = _forMonth(year, month);
    final report = await reports.report(ReportPeriod.monthOf(year, month));

    final spendByCategory = {
      for (final slice in report.categories) slice.categoryId: slice,
    };

    final overallBudget = budgets.where((b) => b.isOverall).firstOrNull;

    final categories = [
      for (final budget in budgets.where((b) => !b.isOverall))
        _progressFor(budget, spendByCategory[budget.categoryId]),
    ]..sort(_mostPressingFirst);

    var budgeted = 0;
    for (final budget in budgets.where((b) => !b.isOverall)) {
      budgeted += budget.amount.minorUnits;
    }

    final budgetedCategoryIds = {
      for (final budget in budgets.where((b) => !b.isOverall))
        budget.categoryId,
    };
    var unbudgeted = 0;
    for (final slice in report.categories) {
      if (!budgetedCategoryIds.contains(slice.categoryId)) {
        unbudgeted += slice.amount.minorUnits;
      }
    }

    return BudgetBoard(
      overall: overallBudget == null
          ? null
          : _overallProgress(overallBudget, report),
      categories: categories,
      totalBudgeted: Money(budgeted),
      totalSpent: report.expenses,
      unbudgetedSpending: Money(unbudgeted),
    );
  }

  @override
  Future<List<Budget>> forMonth({
    required int year,
    required int month,
  }) async => _forMonth(year, month);

  @override
  Future<Budget?> byId(String id) async {
    for (final budget in _budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }

  // ------------------------------------------------------------- writing

  @override
  Future<Budget> create(Budget budget) async {
    await Future<void>.delayed(delay);
    _budgets.add(budget);
    await store?.write(_budgets);
    return budget;
  }

  @override
  Future<Budget> update(Budget budget) async {
    await Future<void>.delayed(delay);

    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index == -1) throw StateError('No budget with id ${budget.id}');

    _budgets[index] = budget;
    await store?.write(_budgets);
    return budget;
  }

  @override
  Future<void> delete(String id) async {
    await Future<void>.delayed(delay);
    _budgets.removeWhere((b) => b.id == id);
    await store?.write(_budgets);
  }

  String newId() {
    _nextId++;
    return 'budget-${now().microsecondsSinceEpoch}-$_nextId';
  }

  // ---------------------------------------------------- the arithmetic

  List<Budget> _forMonth(int year, int month) =>
      _budgets.where((b) => b.year == year && b.month == month).toList();

  BudgetProgress _progressFor(Budget budget, CategorySlice? slice) {
    final spent = slice?.amount.minorUnits ?? 0;
    return _build(budget, spent, slice?.transactionCount ?? 0);
  }

  BudgetProgress _overallProgress(Budget budget, ReportData report) =>
      _build(budget, report.expenses.minorUnits, report.transactionCount);

  BudgetProgress _build(Budget budget, int spent, int transactionCount) {
    final limit = budget.amount.minorUnits;

    final remaining = limit - spent;

    return BudgetProgress(
      budget: budget,
      spent: Money(spent),
      remaining: Money(remaining),
      overspend: Money(remaining < 0 ? -remaining : 0),
      // Guarded: a zero limit cannot have a meaningful ratio, and a NaN
      // paints a progress bar of indeterminate length. The validator
      // refuses zero, so this is belt and braces for stored data from an
      // older build.
      ratio: limit == 0 ? 0 : spent / limit,
      status: thresholds.levelFor(limit == 0 ? 0 : spent / limit),
      transactionCount: transactionCount,
    );
  }

  /// Trouble first.
  ///
  /// A list sorted by amount buries the one category that is over its
  /// limit under four that are fine. Sorting by how close each is to its
  /// limit puts the thing worth acting on at the top, which is the only
  /// reason to open this screen in a hurry.
  static int _mostPressingFirst(BudgetProgress a, BudgetProgress b) {
    final byRatio = b.ratio.compareTo(a.ratio);
    if (byRatio != 0) return byRatio;
    // Same pressure: the bigger commitment first.
    return b.budget.amount.minorUnits.compareTo(a.budget.amount.minorUnits);
  }

  // ----------------------------------------------------------- seed data

  /// A plausible set of plans for the current month.
  ///
  /// Sized against what the generated history actually spends, so the
  /// screen opens showing a real mix — most categories fine, one close,
  /// one over — rather than everything comfortably green or everything
  /// alarming.
  static List<Budget> _seedFor(DateTime now) {
    var sequence = 0;
    Budget make({
      required BudgetKind kind,
      required int amount,
      String? categoryId,
      String? categoryLabel,
      String description = '',
    }) {
      sequence++;
      return Budget(
        id: 'seed-budget-$sequence',
        kind: kind,
        amount: Money(amount),
        year: now.year,
        month: now.month,
        categoryId: categoryId,
        categoryLabel: categoryLabel,
        description: description,
      );
    }

    return [
      make(
        kind: BudgetKind.overall,
        amount: 1400000,
        description: 'Everything this month',
      ),
      make(
        kind: BudgetKind.category,
        amount: 500000,
        categoryId: 'housing',
        categoryLabel: 'Housing',
        description: 'Rent contribution',
      ),
      make(
        kind: BudgetKind.category,
        amount: 250000,
        categoryId: 'food',
        categoryLabel: 'Food',
      ),
      make(
        kind: BudgetKind.category,
        amount: 60000,
        categoryId: 'bills',
        categoryLabel: 'Bills',
      ),
      make(
        kind: BudgetKind.category,
        amount: 30000,
        categoryId: 'entertainment',
        categoryLabel: 'Entertainment',
      ),
      make(
        kind: BudgetKind.category,
        amount: 40000,
        categoryId: 'transport',
        categoryLabel: 'Transport',
      ),
    ];
  }
}
