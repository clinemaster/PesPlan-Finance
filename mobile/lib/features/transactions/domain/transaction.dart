import '../../../core/money/money.dart';

/// Money in, or money out. The one distinction the whole feature turns on.
enum TransactionType {
  income,
  expense;

  String get label => switch (this) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
  };

  bool get isIncome => this == TransactionType.income;
}

/// One recorded movement of money.
///
/// ## The sign lives in [amount], and is set once
///
/// [amount] is signed: negative for an expense, positive for income. That
/// matches the design system — `MoneyText` and `TransactionTile` colour and
/// prefix from the sign — so no widget has to pair an amount with a type to
/// know how to draw it, and no widget can get that pairing wrong.
///
/// The form collects a magnitude and a type and calls [create], which
/// applies the sign in one place. That is sign assignment from an explicit
/// user choice, not a derived financial result, so it does not breach the
/// rule against computing money in Dart: nothing here sums, nets or
/// evaluates anything.
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryLabel,
    required this.date,
    required this.createdAt,
    this.description = '',
  });

  /// Builds a transaction from what the form collects.
  ///
  /// [magnitudeMinorUnits] is always positive — the amount field cannot
  /// produce a negative — and the type decides the sign.
  factory Transaction.create({
    required String id,
    required TransactionType type,
    required int magnitudeMinorUnits,
    required String categoryId,
    required String categoryLabel,
    required DateTime date,
    required DateTime createdAt,
    String description = '',
    Currency currency = Currency.tzs,
  }) {
    final magnitude = magnitudeMinorUnits.abs();
    return Transaction(
      id: id,
      type: type,
      amount: Money(
        type.isIncome ? magnitude : -magnitude,
        currency: currency,
      ),
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      date: date,
      createdAt: createdAt,
      description: description,
    );
  }

  final String id;
  final TransactionType type;

  /// Signed. Negative is money out.
  final Money amount;

  /// Lowercase key, resolved to an icon by `AppIcons.forCategory`.
  final String categoryId;

  /// Human-readable category, as shown in the list.
  final String categoryLabel;

  /// Optional note. Empty means the user did not add one, and the row falls
  /// back to the category name rather than showing a blank line.
  final String description;

  /// The day the money moved, which is not necessarily when it was typed in.
  final DateTime date;

  /// When the record was created. Breaks ties for same-day ordering, so a
  /// list does not reshuffle between builds.
  final DateTime createdAt;

  Currency get currency => amount.currency;

  /// What the row shows as its headline. A description if there is one,
  /// otherwise the category — never an empty line.
  String get title => description.trim().isEmpty
      ? categoryLabel
      : description.trim();

  /// Everything a search should look at, lowercased once.
  String get searchHaystack =>
      '$description $categoryLabel $categoryId'.toLowerCase();

  Transaction copyWith({
    TransactionType? type,
    Money? amount,
    String? categoryId,
    String? categoryLabel,
    String? description,
    DateTime? date,
  }) => Transaction(
    id: id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    categoryLabel: categoryLabel ?? this.categoryLabel,
    description: description ?? this.description,
    date: date ?? this.date,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) => other is Transaction && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Transaction($id, ${type.name}, $amount)';
}
