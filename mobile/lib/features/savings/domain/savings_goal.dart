import '../../../core/money/money.dart';

/// A picture for a goal, chosen from a short list.
///
/// ## Keys, not icons
///
/// Each entry carries a lowercase key the design system already resolves
/// through `AppIcons.forCategory`, so a goal stores a string rather than
/// an `IconData` — which is what lets it be written to storage, sent to a
/// server later, and rendered by the same `CategoryIcon` every other
/// feature uses.
class GoalIcon {
  const GoalIcon(this.key, this.label);

  final String key;
  final String label;

  /// The set offered on the form.
  ///
  /// Eight, deliberately. A longer grid turns a thirty-second task into a
  /// browsing exercise, and the eight cover what people in the launch
  /// market actually save toward.
  static const List<GoalIcon> all = [
    GoalIcon('savings', 'Savings'),
    GoalIcon('education', 'Education'),
    GoalIcon('travel', 'Travel'),
    GoalIcon('housing', 'Home'),
    GoalIcon('transport', 'Vehicle'),
    GoalIcon('business', 'Business'),
    GoalIcon('airtime', 'Device'),
    GoalIcon('other', 'Other'),
  ];

  static const String fallback = 'savings';

  /// The label for a stored key, for the form's current selection.
  static String labelFor(String key) {
    for (final icon in all) {
      if (icon.key == key) return icon.label;
    }
    return 'Other';
  }
}

/// Something a user is saving toward.
///
/// ## The plan only — nothing here knows the balance
///
/// A goal is a name, a target and a picture. What has actually been put
/// aside is the sum of its movements, which is a property of
/// [GoalMovement] records rather than of this object. Keeping a `saved`
/// field here would mean every stored goal carried a figure that goes
/// stale the moment a contribution is recorded, and two places to fix
/// when they disagree. [GoalProgress] pairs the two.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.createdAt,
    this.iconKey = GoalIcon.fallback,
    this.targetDate,
    this.description = '',
  });

  final String id;
  final String name;

  /// What the user is saving toward. Always positive.
  final Money target;

  /// When the goal was created. Shown on the detail screen, and used for
  /// the dashboard's caption when there is no target date.
  final DateTime createdAt;

  /// A key from [GoalIcon.all].
  final String iconKey;

  /// Optional. A goal with no date is a goal all the same — "when I can"
  /// is how most emergency funds are actually saved.
  final DateTime? targetDate;

  final String description;

  bool get hasTargetDate => targetDate != null;

  SavingsGoal copyWith({
    String? name,
    Money? target,
    String? iconKey,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? description,
  }) => SavingsGoal(
    id: id,
    name: name ?? this.name,
    target: target ?? this.target,
    createdAt: createdAt,
    iconKey: iconKey ?? this.iconKey,
    targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) => other is SavingsGoal && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SavingsGoal($id, $name, $target)';
}
