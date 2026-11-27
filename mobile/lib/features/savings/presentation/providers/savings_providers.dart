import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../../core/time/clock.dart';
import '../../data/mock_savings_repository.dart';
import '../../data/savings_store.dart';
import '../../domain/goal_movement.dart';
import '../../domain/goal_progress.dart';
import '../../domain/savings_goal.dart';
import '../../domain/savings_repository.dart';

/// Where savings goals live.
///
/// Phase 16 overrides this with an API-backed implementation; nothing
/// above it changes.
final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => MockSavingsRepository(
    now: ref.watch(clockProvider),
    store: SavingsStore(ref.watch(keyValueStoreProvider)),
  ),
);

/// Every goal, measured.
final savingsBoardProvider = FutureProvider<SavingsBoard>(
  (ref) => ref.read(savingsRepositoryProvider).board(),
);

/// One goal's progress, for the detail screen.
///
/// Watches the board so recording a contribution anywhere refreshes it,
/// rather than leaving the screen the user is looking at behind.
final goalProgressProvider = FutureProvider.family<GoalProgress?, String>((
  ref,
  id,
) async {
  ref.watch(savingsBoardProvider);
  return ref.read(savingsRepositoryProvider).progressFor(id);
});

/// One goal, for the edit form.
final goalByIdProvider = FutureProvider.family<SavingsGoal?, String>((
  ref,
  id,
) async {
  ref.watch(savingsBoardProvider);
  return ref.read(savingsRepositoryProvider).byId(id);
});

/// A goal's movements, newest first.
final goalMovementsProvider = FutureProvider.family<List<GoalMovement>, String>(
  (ref, id) async {
    ref.watch(savingsBoardProvider);
    return ref.read(savingsRepositoryProvider).movements(id);
  },
);

/// Writes, plus the rebuild every write needs.
class SavingsActions {
  const SavingsActions(this._ref);

  final Ref _ref;

  SavingsRepository get _repository => _ref.read(savingsRepositoryProvider);

  String newId() {
    final repository = _repository;
    return repository is MockSavingsRepository
        ? repository.newId()
        : DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<SavingsGoal> create(
    SavingsGoal goal, {
    int initialMinorUnits = 0,
  }) async {
    final saved = await _repository.create(
      goal,
      initialMinorUnits: initialMinorUnits,
    );
    _invalidate();
    return saved;
  }

  Future<SavingsGoal> update(SavingsGoal goal) async {
    final saved = await _repository.update(goal);
    _invalidate();
    return saved;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _invalidate();
  }

  Future<GoalMovement> addMovement(GoalMovement movement) async {
    final saved = await _repository.addMovement(movement);
    _invalidate();
    return saved;
  }

  /// One invalidation, at the board: everything else watches it, so the
  /// card, the detail screen, the history and the dashboard all refresh
  /// from a single write.
  void _invalidate() => _ref.invalidate(savingsBoardProvider);
}

final savingsActionsProvider = Provider<SavingsActions>(SavingsActions.new);
