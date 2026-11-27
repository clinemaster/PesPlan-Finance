import 'budget.dart';
import 'budget_progress.dart';

/// Where budgets live, and where their progress is worked out.
///
/// The screen asks for a [BudgetBoard] — plans already paired with
/// spending, already ranked, already totalled — rather than a list of
/// budgets it would have to measure itself. That keeps the measuring on
/// the far side of this boundary, which is where a server will do it.
abstract interface class BudgetRepository {
  /// Budgets for one month, with what has been spent against each.
  Future<BudgetBoard> board({required int year, required int month});

  /// Every budget stored for a month, plans only.
  Future<List<Budget>> forMonth({required int year, required int month});

  Future<Budget?> byId(String id);

  Future<Budget> create(Budget budget);

  Future<Budget> update(Budget budget);

  Future<void> delete(String id);
}
