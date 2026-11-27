import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../../core/time/clock.dart';
import '../../../reports/presentation/providers/report_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/budget_store.dart';
import '../../data/mock_budget_repository.dart';
import '../../domain/budget.dart';
import '../../domain/budget_progress.dart';
import '../../domain/budget_repository.dart';
import '../../domain/budget_status.dart';

/// Where a status level begins.
///
/// A provider rather than a constant so the thresholds are one decision
/// the whole feature reads, and so a test can shift them without
/// rewriting a screen.
final budgetThresholdsProvider = Provider<BudgetThresholds>(
  (ref) => BudgetThresholds.standard,
);

/// Where budgets live.
///
/// Built on the report repository, so what a budget says was spent is
/// what every other screen says was spent.
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => MockBudgetRepository(
    reports: ref.watch(reportRepositoryProvider),
    now: ref.watch(clockProvider),
    thresholds: ref.watch(budgetThresholdsProvider),
    store: BudgetStore(ref.watch(keyValueStoreProvider)),
  ),
);

/// Which month the Budgets screen is showing.
class BudgetMonth {
  const BudgetMonth(this.year, this.month);

  factory BudgetMonth.of(DateTime moment) =>
      BudgetMonth(moment.year, moment.month);

  final int year;
  final int month;

  BudgetMonth previous() =>
      month == 1 ? BudgetMonth(year - 1, 12) : BudgetMonth(year, month - 1);

  BudgetMonth next() =>
      month == 12 ? BudgetMonth(year + 1, 1) : BudgetMonth(year, month + 1);

  /// Budgets are plans for a month, and a month that has not started has
  /// nothing to measure. Forward stops at the present.
  bool canGoNext(DateTime now) =>
      year < now.year || (year == now.year && month < now.month);

  bool isCurrent(DateTime now) => year == now.year && month == now.month;

  @override
  bool operator ==(Object other) =>
      other is BudgetMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class BudgetMonthController extends Notifier<BudgetMonth> {
  @override
  BudgetMonth build() => BudgetMonth.of(ref.watch(clockProvider)());

  void select(BudgetMonth month) => state = month;

  void previous() => state = state.previous();

  void next() {
    if (!state.canGoNext(ref.read(clockProvider)())) return;
    state = state.next();
  }
}

final budgetMonthProvider =
    NotifierProvider<BudgetMonthController, BudgetMonth>(
      BudgetMonthController.new,
    );

/// The month's budgets, measured.
final budgetBoardProvider = FutureProvider<BudgetBoard>((ref) async {
  final month = ref.watch(budgetMonthProvider);

  // Depends on the transaction list so recording an expense moves the
  // bars rather than leaving a stale picture of the month.
  ref.watch(transactionListProvider);

  return ref
      .read(budgetRepositoryProvider)
      .board(year: month.year, month: month.month);
});

/// The plans for the selected month, for the duplicate check on the form.
final budgetsForMonthProvider = FutureProvider<List<Budget>>((ref) async {
  final month = ref.watch(budgetMonthProvider);
  ref.watch(budgetBoardProvider);

  return ref
      .read(budgetRepositoryProvider)
      .forMonth(year: month.year, month: month.month);
});

/// One budget, for the edit form.
final budgetByIdProvider = FutureProvider.family<Budget?, String>((
  ref,
  id,
) async {
  ref.watch(budgetBoardProvider);
  return ref.read(budgetRepositoryProvider).byId(id);
});

/// Writes, plus the rebuild every write needs.
class BudgetActions {
  const BudgetActions(this._ref);

  final Ref _ref;

  BudgetRepository get _repository => _ref.read(budgetRepositoryProvider);

  String newId() {
    final repository = _repository;
    return repository is MockBudgetRepository
        ? repository.newId()
        : DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<Budget> create(Budget budget) async {
    final saved = await _repository.create(budget);
    _invalidate();
    return saved;
  }

  Future<Budget> update(Budget budget) async {
    final saved = await _repository.update(budget);
    _invalidate();
    return saved;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _invalidate();
  }

  void _invalidate() => _ref.invalidate(budgetBoardProvider);
}

final budgetActionsProvider = Provider<BudgetActions>(BudgetActions.new);
