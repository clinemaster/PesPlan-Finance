import 'goal_movement.dart';
import 'goal_progress.dart';
import 'savings_goal.dart';

/// Where savings goals come from.
///
/// Phase 16 replaces the mock with an API-backed implementation; nothing
/// above this interface changes when it does. Every figure the UI needs
/// arrives already computed (see [GoalProgress]), so the swap cannot
/// quietly move arithmetic into Dart.
abstract interface class SavingsRepository {
  /// Every goal, split into active and completed, with the totals.
  Future<SavingsBoard> board();

  /// One goal's progress, or null when it is gone — which is a real case,
  /// since Delete sits beside Edit on the detail screen.
  Future<GoalProgress?> progressFor(String id);

  Future<SavingsGoal?> byId(String id);

  /// The goal's movements, newest first.
  Future<List<GoalMovement>> movements(String goalId);

  Future<SavingsGoal> create(SavingsGoal goal, {int initialMinorUnits = 0});

  Future<SavingsGoal> update(SavingsGoal goal);

  /// Removes the goal and its movements. The user is asked first.
  Future<void> delete(String id);

  /// Records money put aside.
  Future<GoalMovement> addMovement(GoalMovement movement);
}
