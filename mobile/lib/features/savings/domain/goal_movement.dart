import '../../../core/money/money.dart';

/// Money into a goal, or money back out of it.
enum MovementKind {
  contribution,
  withdrawal;

  String get label => switch (this) {
    MovementKind.contribution => 'Contribution',
    MovementKind.withdrawal => 'Withdrawal',
  };

  /// The verb the confirmation uses.
  String get pastTense => switch (this) {
    MovementKind.contribution => 'added',
    MovementKind.withdrawal => 'taken out',
  };

  bool get isContribution => this == MovementKind.contribution;
}

/// One movement of money into or out of a goal.
///
/// ## Amounts are magnitudes, and the kind carries the direction
///
/// Unlike [Transaction], which signs its amount, a movement keeps a
/// positive [amount] and states its direction in [kind]. A savings goal
/// has no ledger sign: putting 50,000 aside and taking 50,000 back are
/// the same quantity moving opposite ways, and the screen reads [kind] to
/// decide the arrow and the colour.
///
/// ## These are not transactions
///
/// Setting money aside is not spending it. A contribution is recorded
/// here and nowhere else — it never reaches the transaction repository,
/// so it cannot appear as an expense, cannot move the month's net, and
/// cannot be counted twice by the reports that read transactions.
class GoalMovement {
  const GoalMovement({
    required this.id,
    required this.goalId,
    required this.kind,
    required this.amount,
    required this.date,
    required this.recordedAt,
    this.description = '',
  });

  final String id;
  final String goalId;
  final MovementKind kind;

  /// Always positive. [kind] says which way it went.
  final Money amount;

  /// The day the user says it happened.
  final DateTime date;

  /// When the app recorded it. Breaks ties when two movements share a day,
  /// so the history has a stable order.
  final DateTime recordedAt;

  final String description;

  bool get isContribution => kind.isContribution;

  /// What the history row says when the user left the note empty.
  String get title =>
      description.trim().isEmpty ? kind.label : description.trim();

  @override
  bool operator ==(Object other) => other is GoalMovement && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GoalMovement($id, ${kind.name}, $amount)';
}
