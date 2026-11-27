import 'budget.dart';

/// Validation for the budget form.
///
/// Pure functions returning a user-facing message, or `null` when the
/// value is acceptable — the shape the design system's fields take, so a
/// screen passes the result straight through.
abstract final class BudgetValidator {
  /// A hard ceiling, catching a held-down key rather than a real plan.
  static const int maxMinorUnits = 10000000000;

  static const int maxDescriptionLength = 80;

  /// The limit. Required and positive.
  ///
  /// Zero is rejected rather than treated as "no spending allowed": a
  /// budget of nothing is almost always a half-typed number, and the way
  /// to plan for no spending in a category is not to budget it.
  static String? amount(int? minorUnits) {
    if (minorUnits == null) return 'Enter an amount';
    if (minorUnits <= 0) return 'Enter an amount greater than zero';
    if (minorUnits > maxMinorUnits) {
      return 'That amount looks too large — check the figure';
    }
    return null;
  }

  /// The category. Required for a category budget, meaningless otherwise.
  static String? category(BudgetKind kind, String? categoryId) {
    if (kind == BudgetKind.overall) return null;
    return (categoryId ?? '').isEmpty ? 'Choose a category' : null;
  }

  static String? description(String? value) {
    final text = (value ?? '').trim();
    if (text.length > maxDescriptionLength) {
      return 'Keep it under $maxDescriptionLength characters';
    }
    return null;
  }

  /// Whether the month already has a budget this one would duplicate.
  ///
  /// Two budgets for the same category in the same month cannot both be
  /// the plan, and the arithmetic below them would double-count. Caught
  /// here, where it can be explained, rather than by letting the list
  /// show two bars for Food.
  static String? duplicate({
    required BudgetKind kind,
    required String? categoryId,
    required List<Budget> existing,
    String? editingId,
  }) {
    for (final budget in existing) {
      if (budget.id == editingId) continue;
      if (budget.kind != kind) continue;

      if (kind == BudgetKind.overall) {
        return 'This month already has an overall budget. Edit that one '
            'instead.';
      }
      if (budget.categoryId == categoryId) {
        return '${budget.categoryLabel} already has a budget this month. '
            'Edit that one instead.';
      }
    }
    return null;
  }

  /// Whether the form as a whole may be saved.
  static bool canSave({
    required BudgetKind kind,
    required int? minorUnits,
    required String? categoryId,
    required String? description,
    required List<Budget> existing,
    String? editingId,
  }) =>
      amount(minorUnits) == null &&
      category(kind, categoryId) == null &&
      BudgetValidator.description(description) == null &&
      duplicate(
            kind: kind,
            categoryId: categoryId,
            existing: existing,
            editingId: editingId,
          ) ==
          null;
}
