import '../../../core/money/money.dart';
import '../domain/goal_movement.dart';
import '../domain/goal_progress.dart';
import '../domain/savings_goal.dart';
import '../domain/savings_repository.dart';
import 'savings_store.dart';

/// Savings goals, measured from their own movements.
///
/// ## A goal's balance is its history, added up
///
/// Nothing stores "saved so far". Every figure — saved, remaining, the
/// ratio, whether a goal is finished — is derived here from the
/// [GoalMovement] records, so the number on the card and the list of
/// movements behind it cannot disagree. A stored balance would be a
/// second source of truth, and the first thing to go stale.
///
/// ## Contributions are not spending
///
/// Movements live only here. A contribution never reaches the transaction
/// repository, which is what keeps money set aside out of the month's
/// expenses, out of the reports, and out of the budget bars — putting
/// 100,000 into an emergency fund is not a 100,000 expense, and counting
/// it as one would overstate spending for every user who saves.
///
/// ## The fifth file allowed to add up money
///
/// Architecture Rule 1 keeps financial arithmetic out of the app. This
/// class plays the server while the data is mocked, so progress arrives
/// above [SavingsRepository] already computed.
/// `test/transactions/architecture_test.dart` fails the build if any of
/// it leaks upward.
class MockSavingsRepository implements SavingsRepository {
  factory MockSavingsRepository({
    required DateTime Function() now,
    List<SavingsGoal>? seedGoals,
    List<GoalMovement>? seedMovements,
    SavingsStore? store,
    Duration delay = const Duration(milliseconds: 250),
  }) {
    // Goals and movements are decided together, in one pass.
    //
    // Deciding them separately looked tidier and was wrong: writing the
    // seeded goals set `hasStoredData`, so the movements then read a
    // store that had goals but no movements yet and came back with a
    // const empty list — which the first contribution could not be added
    // to. One decision, one write, no half-written state.
    final (goals, movements) = _initial(
      now: now,
      seedGoals: seedGoals,
      seedMovements: seedMovements,
      store: store,
    );

    return MockSavingsRepository._(
      goals,
      movements,
      now: now,
      store: store,
      delay: delay,
    );
  }

  MockSavingsRepository._(
    this._goals,
    this._movements, {
    required this.now,
    required this.store,
    required this.delay,
  });

  final DateTime Function() now;

  final SavingsStore? store;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  final List<SavingsGoal> _goals;
  final List<GoalMovement> _movements;

  int _nextId = 0;

  /// Everything held, for tests and for the duplicate-name check.
  List<SavingsGoal> get allGoals => List.unmodifiable(_goals);

  List<GoalMovement> get allMovements => List.unmodifiable(_movements);

  /// What the repository starts with: a caller's seed, what was stored,
  /// or a generated demo account — written back so the next launch finds
  /// it.
  static (List<SavingsGoal>, List<GoalMovement>) _initial({
    required DateTime Function() now,
    required List<SavingsGoal>? seedGoals,
    required List<GoalMovement>? seedMovements,
    required SavingsStore? store,
  }) {
    // Seeded goals bring their own history, even when that is none: a
    // test that asks for two empty goals must not be handed the demo
    // account's movements.
    if (seedGoals != null) {
      return ([...seedGoals], [...?seedMovements]);
    }

    if (store != null && store.hasStoredData) {
      return ([...store.readGoals()], [...store.readMovements()]);
    }

    final goals = _seedGoals(now());
    final movements = _seedMovements(now());
    store?.writeGoals(goals);
    store?.writeMovements(movements);
    return (goals, movements);
  }

  // ------------------------------------------------------------- reading

  @override
  Future<SavingsBoard> board() async {
    await Future<void>.delayed(delay);

    final progress = [for (final goal in _goals) _progressFor(goal)];

    final active = [
      for (final p in progress)
        if (!p.isComplete) p,
    ]..sort(_closestToDoneFirst);
    final completed = [
      for (final p in progress)
        if (p.isComplete) p,
    ]..sort(_mostRecentlyFinishedFirst);

    var saved = 0;
    var target = 0;
    for (final p in active) {
      saved += p.saved.minorUnits;
      target += p.goal.target.minorUnits;
    }

    return SavingsBoard(
      active: active,
      completed: completed,
      totalSaved: Money(saved),
      totalTarget: Money(target),
      ratio: target == 0 ? 0 : saved / target,
    );
  }

  @override
  Future<GoalProgress?> progressFor(String id) async {
    await Future<void>.delayed(delay);

    for (final goal in _goals) {
      if (goal.id == id) return _progressFor(goal);
    }
    return null;
  }

  @override
  Future<SavingsGoal?> byId(String id) async {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  @override
  Future<List<GoalMovement>> movements(String goalId) async {
    await Future<void>.delayed(delay);
    return _movementsFor(goalId);
  }

  // ------------------------------------------------------------- writing

  @override
  Future<SavingsGoal> create(
    SavingsGoal goal, {
    int initialMinorUnits = 0,
  }) async {
    await Future<void>.delayed(delay);

    _goals.add(goal);

    // An opening amount is recorded as a contribution rather than stored
    // on the goal, so a goal that starts at 200,000 has the same shape as
    // one that got there by saving — one history, one way to read it.
    if (initialMinorUnits > 0) {
      _movements.add(
        GoalMovement(
          id: newId(),
          goalId: goal.id,
          kind: MovementKind.contribution,
          amount: Money(initialMinorUnits),
          date: goal.createdAt,
          recordedAt: now(),
          description: 'Already saved',
        ),
      );
    }

    await _persist();
    return goal;
  }

  @override
  Future<SavingsGoal> update(SavingsGoal goal) async {
    await Future<void>.delayed(delay);

    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index == -1) throw StateError('No goal with id ${goal.id}');

    // Replaced in place, and the movements are not touched: lowering a
    // target can complete a goal, but it must never rewrite what was
    // actually put in or taken out.
    _goals[index] = goal;
    await _persist();
    return goal;
  }

  @override
  Future<void> delete(String id) async {
    await Future<void>.delayed(delay);

    _goals.removeWhere((goal) => goal.id == id);
    _movements.removeWhere((movement) => movement.goalId == id);
    await _persist();
  }

  @override
  Future<GoalMovement> addMovement(GoalMovement movement) async {
    await Future<void>.delayed(delay);

    if (!_goals.any((goal) => goal.id == movement.goalId)) {
      throw StateError('No goal with id ${movement.goalId}');
    }

    // The backstop for the rule the form already enforces. A goal cannot
    // hold less than nothing, and a client that forgot to check must not
    // be able to produce that state on the server's side of the line.
    if (!movement.isContribution) {
      final saved = _savedMinorUnits(movement.goalId);
      if (movement.amount.minorUnits > saved) {
        throw StateError('A withdrawal cannot exceed what the goal holds');
      }
    }

    _movements.add(movement);
    await _persist();
    return movement;
  }

  String newId() {
    _nextId++;
    return 'savings-${now().microsecondsSinceEpoch}-$_nextId';
  }

  Future<void> _persist() async {
    await store?.writeGoals(_goals);
    await store?.writeMovements(_movements);
  }

  // ---------------------------------------------------- the arithmetic

  List<GoalMovement> _movementsFor(String goalId) => [
    for (final m in _movements)
      if (m.goalId == goalId) m,
  ]..sort(_newestFirst);

  int _savedMinorUnits(String goalId) {
    var saved = 0;
    for (final movement in _movements) {
      if (movement.goalId != goalId) continue;
      saved += movement.isContribution
          ? movement.amount.minorUnits
          : -movement.amount.minorUnits;
    }
    return saved < 0 ? 0 : saved;
  }

  GoalProgress _progressFor(SavingsGoal goal) {
    var contributed = 0;
    var withdrawn = 0;
    var count = 0;
    DateTime? last;

    for (final movement in _movements) {
      if (movement.goalId != goal.id) continue;
      count++;
      if (movement.isContribution) {
        contributed += movement.amount.minorUnits;
      } else {
        withdrawn += movement.amount.minorUnits;
      }
      if (last == null || movement.date.isAfter(last)) last = movement.date;
    }

    final rawSaved = contributed - withdrawn;
    final saved = rawSaved < 0 ? 0 : rawSaved;
    final target = goal.target.minorUnits;
    final shortfall = target - saved;

    return GoalProgress(
      goal: goal,
      saved: Money(saved),
      // Floored at zero: "−120,000 to go" is not a sentence anyone should
      // read, and over-saving is reported by the ratio instead.
      remaining: Money(shortfall < 0 ? 0 : shortfall),
      // Guarded: a zero target cannot have a meaningful ratio, and a NaN
      // paints a bar of indeterminate length. The validator refuses zero,
      // so this is for data stored by an older build.
      ratio: target == 0 ? 0 : saved / target,
      isComplete: target > 0 && saved >= target,
      contributed: Money(contributed),
      withdrawn: Money(withdrawn),
      movementCount: count,
      lastMovement: last,
    );
  }

  /// Closest to done first.
  ///
  /// The goal a user is about to finish is the one worth seeing, and the
  /// one most likely to get the next contribution. Sorting by amount
  /// would bury it under whichever goal happens to be largest.
  static int _closestToDoneFirst(GoalProgress a, GoalProgress b) {
    final byRatio = b.ratio.compareTo(a.ratio);
    if (byRatio != 0) return byRatio;
    return b.goal.target.minorUnits.compareTo(a.goal.target.minorUnits);
  }

  static int _mostRecentlyFinishedFirst(GoalProgress a, GoalProgress b) {
    final aAt = a.lastMovement;
    final bAt = b.lastMovement;
    if (aAt == null || bAt == null) return 0;
    return bAt.compareTo(aAt);
  }

  static int _newestFirst(GoalMovement a, GoalMovement b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    // Two movements on the same day keep the order they were recorded in,
    // newest on top, so a correction sits above what it corrects.
    return b.recordedAt.compareTo(a.recordedAt);
  }

  // ----------------------------------------------------------- seed data

  /// A plausible set of goals for review.
  ///
  /// Sized so the screen opens on a real mix: one goal well under way,
  /// two early, and one finished — so the completed section, the
  /// progress levels and a withdrawal in the history are all visible
  /// without anyone having to create data first.
  static List<SavingsGoal> _seedGoals(DateTime now) => [
    SavingsGoal(
      id: 'goal-emergency',
      name: 'Emergency fund',
      target: const Money(2000000),
      createdAt: DateTime(now.year, 6, 12),
      iconKey: 'savings',
      description: 'Three months of essentials',
    ),
    SavingsGoal(
      id: 'goal-laptop',
      name: 'New laptop',
      target: const Money(1500000),
      createdAt: DateTime(now.year, 9),
      iconKey: 'airtime',
      targetDate: DateTime(now.year + 1, 3, 31),
    ),
    SavingsGoal(
      id: 'goal-zanzibar',
      name: 'Trip to Zanzibar',
      target: const Money(600000),
      createdAt: DateTime(now.year, 10, 5),
      iconKey: 'travel',
      targetDate: DateTime(now.year + 1, 6, 30),
      description: 'Four days, off season',
    ),
    SavingsGoal(
      id: 'goal-school',
      name: 'School fees',
      target: const Money(900000),
      createdAt: DateTime(now.year, 1, 15),
      iconKey: 'education',
      targetDate: DateTime(now.year, 12, 20),
    ),
  ];

  static List<GoalMovement> _seedMovements(DateTime now) {
    var sequence = 0;
    GoalMovement move({
      required String goalId,
      required int amount,
      required DateTime date,
      MovementKind kind = MovementKind.contribution,
      String description = '',
    }) {
      sequence++;
      return GoalMovement(
        id: 'seed-movement-$sequence',
        goalId: goalId,
        kind: kind,
        amount: Money(amount),
        date: date,
        recordedAt: date,
        description: description,
      );
    }

    return [
      // Emergency fund: 850,000 of 2,000,000, including one withdrawal —
      // the case a history that only ever goes up would never show.
      move(
        goalId: 'goal-emergency',
        amount: 300000,
        date: DateTime(now.year, 6, 28),
        description: 'First month',
      ),
      move(
        goalId: 'goal-emergency',
        amount: 250000,
        date: DateTime(now.year, 8, 26),
      ),
      move(
        goalId: 'goal-emergency',
        amount: 50000,
        date: DateTime(now.year, 9, 14),
        kind: MovementKind.withdrawal,
        description: 'Hospital deposit',
      ),
      move(
        goalId: 'goal-emergency',
        amount: 200000,
        date: DateTime(now.year, 10, 27),
      ),
      move(
        goalId: 'goal-emergency',
        amount: 150000,
        date: DateTime(now.year, 11, 25),
        description: 'Payday',
      ),

      // New laptop: 300,000 of 1,500,000.
      move(
        goalId: 'goal-laptop',
        amount: 200000,
        date: DateTime(now.year, 9, 27),
      ),
      move(
        goalId: 'goal-laptop',
        amount: 100000,
        date: DateTime(now.year, 10, 28),
      ),

      // Zanzibar: 100,000 of 600,000.
      move(
        goalId: 'goal-zanzibar',
        amount: 100000,
        date: DateTime(now.year, 10, 20),
        description: 'Deposit saved',
      ),

      // School fees: finished.
      move(
        goalId: 'goal-school',
        amount: 400000,
        date: DateTime(now.year, 2, 10),
      ),
      move(
        goalId: 'goal-school',
        amount: 300000,
        date: DateTime(now.year, 5, 9),
      ),
      move(
        goalId: 'goal-school',
        amount: 200000,
        date: DateTime(now.year, 8, 8),
        description: 'Last instalment',
      ),
    ];
  }
}
