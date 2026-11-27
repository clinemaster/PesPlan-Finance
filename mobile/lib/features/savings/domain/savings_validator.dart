/// Validation for the goal form and the movement forms.
///
/// Pure functions returning a user-facing message, or `null` when the
/// value is acceptable — the shape the design system's fields take, so a
/// screen passes the result straight through.
abstract final class SavingsValidator {
  static const int maxNameLength = 40;
  static const int maxDescriptionLength = 120;

  /// A hard ceiling, catching a held-down key rather than a real target.
  static const int maxMinorUnits = 10000000000;

  /// How far ahead a target date may be set.
  static const int maxYearsAhead = 20;

  static String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Give this goal a name';
    if (text.length > maxNameLength) {
      return 'Keep the name under $maxNameLength characters';
    }
    return null;
  }

  /// The target. Required and positive.
  ///
  /// Zero is refused rather than treated as "no target": a goal with
  /// nothing to reach has no progress to show, and the figure is almost
  /// always half-typed.
  static String? target(int? minorUnits) {
    if (minorUnits == null) return 'Enter a target amount';
    if (minorUnits <= 0) return 'Enter an amount greater than zero';
    if (minorUnits > maxMinorUnits) {
      return 'That amount looks too large — check the figure';
    }
    return null;
  }

  /// What the user has already put aside, if anything.
  ///
  /// Capped at the target so a goal cannot be created already finished —
  /// which would be a completion the app never saw happen, with no
  /// history behind it.
  static String? initialAmount(int? minorUnits, int? targetMinorUnits) {
    if (minorUnits == null || minorUnits == 0) return null;
    if (minorUnits < 0) return 'Enter an amount greater than zero';
    if (targetMinorUnits != null && minorUnits > targetMinorUnits) {
      return 'That is more than the target';
    }
    return null;
  }

  static String? description(String? value) {
    final text = (value ?? '').trim();
    if (text.length > maxDescriptionLength) {
      return 'Keep it under $maxDescriptionLength characters';
    }
    return null;
  }

  /// A target date must be ahead, not behind.
  ///
  /// Only applied to a date the user has just chosen. A goal whose date
  /// has quietly passed keeps it — the date was true when it was set, and
  /// erasing it would lose what the user planned.
  static String? targetDate(DateTime? date, DateTime now) {
    if (date == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final chosen = DateTime(date.year, date.month, date.day);
    if (chosen.isBefore(today)) return 'Choose a date in the future';
    if (chosen.year > now.year + maxYearsAhead) {
      return 'That is further ahead than this app plans for';
    }
    return null;
  }

  /// Money going in.
  static String? contribution(int? minorUnits) {
    if (minorUnits == null) return 'Enter an amount';
    if (minorUnits <= 0) return 'Enter an amount greater than zero';
    if (minorUnits > maxMinorUnits) {
      return 'That amount looks too large — check the figure';
    }
    return null;
  }

  /// Money coming back out.
  ///
  /// [savedMinorUnits] is what the repository says is in the goal. A
  /// withdrawal larger than that would leave negative savings, which is
  /// not a state this product has: the money was never there to take.
  static String? withdrawal(int? minorUnits, int savedMinorUnits) {
    if (minorUnits == null) return 'Enter an amount';
    if (minorUnits <= 0) return 'Enter an amount greater than zero';
    if (savedMinorUnits <= 0) {
      return 'There is nothing in this goal to take out';
    }
    if (minorUnits > savedMinorUnits) {
      return 'That is more than this goal holds';
    }
    return null;
  }

  /// A movement cannot be dated in the future: the user is recording
  /// something that happened, not scheduling one.
  static String? movementDate(DateTime? date, DateTime now) {
    if (date == null) return 'Choose a date';
    final today = DateTime(now.year, now.month, now.day);
    final chosen = DateTime(date.year, date.month, date.day);
    if (chosen.isAfter(today)) return 'Choose today or a past date';
    return null;
  }

  /// Whether the goal form as a whole may be saved.
  static bool canSaveGoal({
    required String? name,
    required int? targetMinorUnits,
    required int? initialMinorUnits,
    required String? description,
    required DateTime? targetDate,
    required DateTime now,
    bool isEditing = false,
  }) =>
      SavingsValidator.name(name) == null &&
      target(targetMinorUnits) == null &&
      SavingsValidator.description(description) == null &&
      SavingsValidator.targetDate(targetDate, now) == null &&
      // An existing goal's balance is already recorded, so the form does
      // not collect an opening amount at all.
      (isEditing || initialAmount(initialMinorUnits, targetMinorUnits) == null);
}
