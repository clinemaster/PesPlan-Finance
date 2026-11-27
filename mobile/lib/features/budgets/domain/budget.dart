import '../../../core/money/money.dart';

/// What a budget covers.
enum BudgetKind {
  /// Everything spent in the month, whatever it was spent on.
  overall,

  /// One category's spending.
  category;

  String get label => switch (this) {
    BudgetKind.overall => 'Overall monthly budget',
    BudgetKind.category => 'Category budget',
  };
}

/// A plan for one month's spending.
///
/// ## Plans only — nothing here knows what was spent
///
/// A budget is a limit the user set. What they actually spent is a
/// property of their transactions, not of this object, so the two are
/// kept apart: [Budget] is what was planned, [BudgetProgress] pairs it
/// with what happened. Putting a `spent` field on here would mean every
/// stored budget carried a figure that goes stale the moment a
/// transaction is recorded.
class Budget {
  const Budget({
    required this.id,
    required this.kind,
    required this.amount,
    required this.year,
    required this.month,
    this.categoryId,
    this.categoryLabel,
    this.description = '',
  });

  final String id;
  final BudgetKind kind;

  /// The limit. Always positive.
  final Money amount;

  /// The month this budget applies to.
  final int year;
  final int month;

  /// Set for a category budget, null for an overall one.
  final String? categoryId;
  final String? categoryLabel;

  /// Optional note from the user.
  final String description;

  bool get isOverall => kind == BudgetKind.overall;

  /// What the list and the detail sheet call it.
  String get name => isOverall ? 'Overall budget' : (categoryLabel ?? 'Budget');

  /// The icon key. Overall budgets borrow the wallet, which is the icon
  /// the Budgets tab already wears.
  String get iconKey => categoryLabel ?? 'budgets';

  Budget copyWith({
    BudgetKind? kind,
    Money? amount,
    int? year,
    int? month,
    String? categoryId,
    String? categoryLabel,
    bool clearCategory = false,
    String? description,
  }) => Budget(
    id: id,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    year: year ?? this.year,
    month: month ?? this.month,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    categoryLabel: clearCategory ? null : (categoryLabel ?? this.categoryLabel),
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) => other is Budget && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Budget($id, ${kind.name}, $amount, $year-$month)';
}
