import '../../../core/money/money.dart';

/// Validation for the transaction form.
///
/// Pure functions returning a user-facing message, or `null` when the value
/// is acceptable — the same shape the design system's fields take for their
/// `error` parameter, so a screen passes the result straight through.
///
/// Frontend validation only: it catches mistakes before the user moves on.
/// The server will validate again when there is one.
abstract final class TransactionValidator {
  /// A hard ceiling, so a mistyped amount is caught rather than stored.
  ///
  /// Ten billion shillings is roughly four million US dollars — far beyond
  /// any personal transaction, and low enough to catch the common slip of
  /// holding a key down.
  static const int maxMinorUnits = 10000000000;

  static const int maxDescriptionLength = 120;

  /// The amount. Required, positive, and within reason.
  ///
  /// [minorUnits] is null when the field is empty or unparseable, which the
  /// amount field reports for us — so this does not re-parse text.
  static String? amount(int? minorUnits, {Currency currency = Currency.tzs}) {
    if (minorUnits == null) return 'Enter an amount';
    if (minorUnits <= 0) return 'Enter an amount greater than zero';
    if (minorUnits > maxMinorUnits) {
      return 'That amount looks too large — check the figure';
    }
    return null;
  }

  /// The category. Required, because an uncategorised transaction makes
  /// every later screen that groups by category quietly wrong.
  static String? category(String? categoryId) =>
      (categoryId ?? '').isEmpty ? 'Choose a category' : null;

  /// The date. Required, and not in the future.
  ///
  /// A future date is almost always a typo in the year, and allowing it
  /// would put entries above "Today" in a list sorted newest first, where
  /// they look like a rendering fault.
  static String? date(DateTime? value, {required DateTime today}) {
    if (value == null) return 'Choose a date';

    final day = DateTime(value.year, value.month, value.day);
    final reference = DateTime(today.year, today.month, today.day);
    if (day.isAfter(reference)) return 'Pick today or a day in the past';

    return null;
  }

  /// The note. Optional, but bounded so one long paste cannot break the
  /// row layout everywhere the description is shown.
  static String? description(String? value) {
    final text = (value ?? '').trim();
    if (text.length > maxDescriptionLength) {
      return 'Keep it under $maxDescriptionLength characters';
    }
    return null;
  }

  /// Whether the form as a whole may be saved.
  ///
  /// Expressed through the field validators rather than repeating their
  /// rules, so the Save button cannot fall out of step with the errors
  /// shown under the fields.
  static bool canSave({
    required int? minorUnits,
    required String? categoryId,
    required DateTime? date,
    required String? description,
    required DateTime today,
  }) =>
      TransactionValidator.amount(minorUnits) == null &&
      TransactionValidator.category(categoryId) == null &&
      TransactionValidator.date(date, today: today) == null &&
      TransactionValidator.description(description) == null;
}
