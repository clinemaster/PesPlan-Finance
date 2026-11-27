import '../../../core/money/money.dart';
import 'savings_goal.dart';

/// A goal paired with what has actually been put aside.
///
/// ## Every figure here arrives computed
///
/// Architecture Rule 1: the app has no financial engine. [saved],
/// [remaining] and [ratio] are produced by the repository from the goal's
/// movements; nothing here or above it derives them.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.saved,
    required this.remaining,
    required this.ratio,
    required this.isComplete,
    required this.contributed,
    required this.withdrawn,
    required this.movementCount,
    this.lastMovement,
  });

  final SavingsGoal goal;

  /// Put aside so far — contributions less withdrawals, never negative.
  final Money saved;

  /// Still to go. Zero once the target is reached, never negative: "you
  /// need −120,000 more" is not a sentence anyone should read.
  final Money remaining;

  /// Saved over target. Can pass 1.0 when someone keeps saving past their
  /// own target, which is a good problem and is reported honestly.
  final double ratio;

  /// True when [saved] has reached the target.
  ///
  /// Supplied rather than compared here, because comparing two amounts is
  /// the kind of reasoning about money this layer does not do.
  final bool isComplete;

  /// Everything ever put in, and everything ever taken back out. The
  /// detail screen shows both so the current figure can be read as a
  /// history rather than a number that moved on its own.
  final Money contributed;
  final Money withdrawn;

  final int movementCount;

  /// When the goal last moved. Null when nothing has been recorded.
  final DateTime? lastMovement;

  /// Whole percent, for display. Capped for the label, not for the data:
  /// a bar cannot be more than full, but the figures behind it stay true.
  int get percent => (ratio * 100).round();

  int get cappedPercent => percent > 100 ? 100 : percent;

  /// What the bar draws. Over-saving fills it and stops.
  double get barValue => ratio > 1 ? 1 : ratio;

  bool get hasMovements => movementCount > 0;
}

/// Every goal, as the Goals screen renders it.
class SavingsBoard {
  const SavingsBoard({
    required this.active,
    required this.completed,
    required this.totalSaved,
    required this.totalTarget,
    required this.ratio,
  });

  static const SavingsBoard empty = SavingsBoard(
    active: [],
    completed: [],
    totalSaved: Money(0),
    totalTarget: Money(0),
    ratio: 0,
  );

  /// Goals still being saved toward, the closest to done first.
  final List<GoalProgress> active;

  /// Goals that have reached their target. Kept, not archived away: they
  /// are the evidence that saving works, which is most of what makes
  /// someone start the next one.
  final List<GoalProgress> completed;

  /// Across the active goals only.
  ///
  /// Completed goals are deliberately left out: rolling them in makes the
  /// headline climb every time one finishes, which reads as progress on
  /// what is left when it is the opposite.
  final Money totalSaved;
  final Money totalTarget;
  final double ratio;

  int get activeCount => active.length;

  int get completedCount => completed.length;

  bool get isEmpty => active.isEmpty && completed.isEmpty;

  bool get hasCompleted => completed.isNotEmpty;

  double get barValue => ratio > 1 ? 1 : ratio;

  int get percent => (ratio * 100).round();
}
