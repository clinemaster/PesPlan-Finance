/// How a budget is doing.
///
/// Four levels rather than two, because "fine" and "over" leaves nothing
/// to say at 85% — which is exactly when a user can still act on the
/// information. The middle two exist to be useful, not to alarm.
enum BudgetStatus {
  /// Comfortable. Said plainly, not celebrated.
  onTrack,

  /// Worth knowing about, not worth worrying about.
  approaching,

  /// Close enough that the rest of the month needs care.
  nearLimit,

  /// Past the limit.
  over;

  /// What the user reads.
  ///
  /// Deliberately calm. "On track" rather than "Great job", "Over budget"
  /// rather than "You overspent!" — a budget is a plan the user made, and
  /// an app that scolds them for missing it is one they stop opening.
  String get label => switch (this) {
    BudgetStatus.onTrack => 'On track',
    BudgetStatus.approaching => 'Approaching limit',
    BudgetStatus.nearLimit => 'Near limit',
    BudgetStatus.over => 'Over budget',
  };

  /// A sentence of context, for the detail view.
  String get explanation => switch (this) {
    BudgetStatus.onTrack => 'Spending is within the plan for this month.',
    BudgetStatus.approaching =>
      'Most of this budget is still available, but it is going quickly.',
    BudgetStatus.nearLimit =>
      'Almost all of this budget is used. What is left will not go far.',
    BudgetStatus.over => 'Spending has passed the limit set for this month.',
  };

  bool get needsAttention =>
      this == BudgetStatus.nearLimit || this == BudgetStatus.over;
}

/// Where one level ends and the next begins.
///
/// ## One place, not scattered through the widgets
///
/// Every component that colours a bar, picks an icon or writes a label
/// asks this. Were the numbers inlined at each call site, changing
/// "approaching" from 75% to 70% would mean finding every one of them,
/// and the first one missed would show a green bar next to an amber
/// label.
class BudgetThresholds {
  const BudgetThresholds({
    this.approaching = 0.75,
    this.nearLimit = 0.90,
    this.over = 1.0,
  });

  /// The defaults. Chosen so the warning arrives while a quarter of the
  /// month's money is still there — early enough to change something.
  static const BudgetThresholds standard = BudgetThresholds();

  /// Share of the limit at which each level begins.
  final double approaching;
  final double nearLimit;
  final double over;

  /// The level for a given share of the limit.
  ///
  /// [ratio] is spent over budgeted, computed by the repository. A budget
  /// of zero cannot have a meaningful ratio, so callers pass what the
  /// repository gave them rather than dividing here.
  BudgetStatus levelFor(double ratio) {
    if (ratio >= over) return BudgetStatus.over;
    if (ratio >= nearLimit) return BudgetStatus.nearLimit;
    if (ratio >= approaching) return BudgetStatus.approaching;
    return BudgetStatus.onTrack;
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetThresholds &&
      other.approaching == approaching &&
      other.nearLimit == nearLimit &&
      other.over == over;

  @override
  int get hashCode => Object.hash(approaching, nearLimit, over);
}
