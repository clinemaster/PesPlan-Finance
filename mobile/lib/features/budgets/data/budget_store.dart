import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/budget.dart';

/// Keeps budgets between launches.
///
/// Same arrangement as transactions: a JSON list behind an interface, so
/// a user's plans survive a restart and the storage choice can change
/// later without a screen noticing.
class BudgetStore {
  const BudgetStore(this._store);

  final KeyValueStore _store;

  static const String _key = 'budgets.all';

  /// True once something has been written, even an empty list — so a user
  /// who deletes their last budget is not handed a fresh set of seeded
  /// ones on the next launch.
  bool get hasStoredData => _store.getString(_key) != null;

  List<Budget> read() {
    final raw = _store.getString(_key);
    if (raw == null) return const [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [for (final entry in list) _decode(entry as Map<String, dynamic>)];
    } on Object {
      // Unreadable state is treated as none: the user loses their plans,
      // which is recoverable, rather than meeting a crash on launch,
      // which is not.
      return const [];
    }
  }

  Future<void> write(List<Budget> budgets) => _store.setString(
    _key,
    jsonEncode([for (final budget in budgets) _encode(budget)]),
  );

  Future<void> clear() => _store.remove(_key);

  static Map<String, dynamic> _encode(Budget budget) => {
    'id': budget.id,
    'kind': budget.kind.name,
    'amount': budget.amount.minorUnits,
    'currency': budget.amount.currency.code,
    'year': budget.year,
    'month': budget.month,
    'categoryId': budget.categoryId,
    'categoryLabel': budget.categoryLabel,
    'description': budget.description,
  };

  static Budget _decode(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    kind: json['kind'] == 'overall' ? BudgetKind.overall : BudgetKind.category,
    amount: Money(
      json['amount'] as int,
      currency: _currencyFor(json['currency'] as String?),
    ),
    year: json['year'] as int,
    month: json['month'] as int,
    categoryId: json['categoryId'] as String?,
    categoryLabel: json['categoryLabel'] as String?,
    description: (json['description'] as String?) ?? '',
  );

  static Currency _currencyFor(String? code) {
    for (final currency in Currency.supported) {
      if (currency.code == code) return currency;
    }
    return Currency.tzs;
  }
}
