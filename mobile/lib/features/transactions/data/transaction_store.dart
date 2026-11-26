import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/transaction.dart';

/// Keeps recorded transactions between launches.
///
/// ## Why a JSON blob and not a database
///
/// There is no server yet, so there is nothing to cache and nothing to
/// query server-side. The architecture doc reserves `drift` for a
/// read-through cache of API payloads, which is a different job from
/// "remember what the user typed", and bringing in a schema, a code
/// generator and a migration story for a few hundred local rows would be
/// paying for all of it up front.
///
/// A few hundred records is roughly a hundred kilobytes of JSON. Writing
/// the whole list on every change is wasteful in principle and
/// imperceptible in practice at this size. If the list ever grows past
/// what one write can carry comfortably, that is the signal to move to
/// `drift` — and the move happens here, behind [TransactionRepository],
/// without touching a screen.
class TransactionStore {
  const TransactionStore(this._store);

  final KeyValueStore _store;

  static const String _key = 'transactions.all';

  /// True once something has been written, even an empty list.
  ///
  /// Distinguishes "this user has deleted everything" from "this is a
  /// first launch" — without it, clearing the last transaction would make
  /// the app helpfully regenerate three years of history.
  bool get hasStoredData => _store.getString(_key) != null;

  List<Transaction> read() {
    final raw = _store.getString(_key);
    if (raw == null) return const [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list) _decode(entry as Map<String, dynamic>),
      ];
    } on Object {
      // Unreadable state — an older shape, or a truncated write. Treated
      // as "nothing stored" so the app still launches; the seed comes
      // back rather than the user facing a crash on start.
      return const [];
    }
  }

  Future<void> write(List<Transaction> transactions) => _store.setString(
    _key,
    jsonEncode([for (final t in transactions) _encode(t)]),
  );

  Future<void> clear() => _store.remove(_key);

  // ------------------------------------------------------------- codec

  static Map<String, dynamic> _encode(Transaction t) => {
    'id': t.id,
    'type': t.type.name,
    // Signed minor units, as stored. Keeping the sign in the number
    // rather than deriving it from the type on read means a record can
    // only ever say one thing about its own direction.
    'amount': t.amount.minorUnits,
    'currency': t.amount.currency.code,
    'categoryId': t.categoryId,
    'categoryLabel': t.categoryLabel,
    'description': t.description,
    'date': t.date.toIso8601String(),
    'createdAt': t.createdAt.toIso8601String(),
  };

  static Transaction _decode(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    type: json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense,
    amount: Money(
      json['amount'] as int,
      currency: _currencyFor(json['currency'] as String?),
    ),
    categoryId: json['categoryId'] as String,
    categoryLabel: json['categoryLabel'] as String,
    description: (json['description'] as String?) ?? '',
    date: DateTime.parse(json['date'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static Currency _currencyFor(String? code) {
    for (final currency in Currency.supported) {
      if (currency.code == code) return currency;
    }
    return Currency.tzs;
  }
}
