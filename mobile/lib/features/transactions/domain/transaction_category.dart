import 'transaction.dart';

/// A category a transaction can be filed under.
///
/// Named in everyday words rather than accounting ones: a user who has
/// never kept books should recognise every option without being taught
/// what it means. "Bills" rather than "utilities and recurring
/// liabilities"; "Food" rather than "groceries and dining".
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.label,
    required this.type,
  });

  /// Lowercase key. Doubles as the icon lookup for `AppIcons.forCategory`.
  final String id;

  final String label;

  /// Which side of the ledger this category belongs to. A category list is
  /// filtered by the type the user picked, so nobody is offered "Salary"
  /// for an expense.
  final TransactionType type;

  @override
  bool operator ==(Object other) =>
      other is TransactionCategory && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() => label;
}

/// The categories this phase offers.
///
/// A deliberately short list. Twenty categories look thorough and get used
/// as five, because a person standing at a till will not scroll; the ones
/// here cover ordinary spending in the launch market, and "Other" catches
/// the rest rather than pretending the list is complete.
abstract final class TransactionCategories {
  const TransactionCategories._();

  static const List<TransactionCategory> expense = [
    TransactionCategory(id: 'food', label: 'Food', type: TransactionType.expense),
    TransactionCategory(
      id: 'transport',
      label: 'Transport',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'shopping',
      label: 'Shopping',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'housing',
      label: 'Housing',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'bills',
      label: 'Bills',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'health',
      label: 'Health',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'education',
      label: 'Education',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'entertainment',
      label: 'Entertainment',
      type: TransactionType.expense,
    ),
    TransactionCategory(
      id: 'other',
      label: 'Other',
      type: TransactionType.expense,
    ),
  ];

  static const List<TransactionCategory> income = [
    TransactionCategory(
      id: 'salary',
      label: 'Salary',
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 'business',
      label: 'Business',
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 'freelance',
      label: 'Freelance',
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 'investment',
      label: 'Investment',
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 'gift',
      label: 'Gift',
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 'other',
      label: 'Other',
      type: TransactionType.income,
    ),
  ];

  /// The categories valid for [type].
  static List<TransactionCategory> forType(TransactionType type) =>
      type.isIncome ? income : expense;

  /// Everything, for the filter sheet — which filters across both sides.
  static List<TransactionCategory> get all => [...expense, ...income];

  /// Looks a category up within its own side of the ledger.
  ///
  /// Scoped by type because "Other" exists on both, and an unscoped lookup
  /// would file an expense under the income version of it.
  static TransactionCategory? find(String id, TransactionType type) {
    for (final category in forType(type)) {
      if (category.id == id) return category;
    }
    return null;
  }
}
