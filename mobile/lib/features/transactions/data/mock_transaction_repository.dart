import '../../../core/money/money.dart';
import '../domain/date_labels.dart';
import '../domain/transaction.dart';
import '../domain/transaction_filter.dart';
import '../domain/transaction_repository.dart';
import '../domain/transaction_view.dart';
import 'transaction_history.dart';

/// An in-memory stand-in for the transactions API.
///
/// ## This is the one file in the app allowed to add up money
///
/// Architecture Rule 1 says the Flutter app contains no financial engine:
/// Dart may format and lay out amounts, never sum, net or evaluate them.
/// That rule protects against the client and the Python reporting layer
/// drifting apart on the six conventions the server encodes.
///
/// A mock that supports adding, editing and deleting cannot hand back
/// pre-authored totals the way the dashboard's mock does — the totals have
/// to move when the data does. So the arithmetic lives here, in the class
/// that *plays the server*, and nowhere else. Everything above
/// [TransactionRepository] receives figures already computed and does not
/// know how they were reached.
///
/// Phase 13 deletes this file and the sums go with it. If a widget, a
/// provider or a domain model ever starts doing its own arithmetic on
/// amounts, that is the defect this arrangement exists to prevent —
/// `test/transactions/architecture_test.dart` fails the build if it does.
class MockTransactionRepository implements TransactionRepository {
  MockTransactionRepository({
    required this.now,
    List<Transaction>? seed,
    this.delay = const Duration(milliseconds: 250),
  }) : _transactions = [...seed ?? _seedFor(now())];

  /// The clock, injected so the seed's relative dates ("Today",
  /// "Yesterday") and the validator agree, and so tests can pin both.
  final DateTime Function() now;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  final List<Transaction> _transactions;

  /// Grows monotonically so two transactions added in the same millisecond
  /// still get distinct ids.
  int _nextId = 0;

  /// Everything held, newest first. For tests and for the empty check.
  List<Transaction> get all => List.unmodifiable(_transactions);

  @override
  Future<TransactionListView> list(TransactionFilter filter) async {
    await Future<void>.delayed(delay);
    return buildView(filter);
  }

  /// The synchronous core of [list].
  ///
  /// Separated so the providers can rebuild a view after a write without
  /// a second simulated round trip, and so tests can exercise filtering
  /// without awaiting anything.
  TransactionListView buildView(TransactionFilter filter) {
    final matches = _transactions.where((t) => _matches(t, filter)).toList()
      ..sort(_newestFirst);

    return TransactionListView(
      groups: _group(matches),
      totals: _totals(matches),
      matchCount: matches.length,
      totalCount: _transactions.length,
    );
  }

  @override
  Future<Transaction?> byId(String id) async {
    for (final transaction in _transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<Transaction> add(Transaction transaction) async {
    await Future<void>.delayed(delay);
    _transactions.add(transaction);
    return transaction;
  }

  @override
  Future<Transaction> update(Transaction transaction) async {
    await Future<void>.delayed(delay);

    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index == -1) {
      throw StateError('No transaction with id ${transaction.id}');
    }
    _transactions[index] = transaction;
    return transaction;
  }

  @override
  Future<void> delete(String id) async {
    await Future<void>.delayed(delay);
    _transactions.removeWhere((t) => t.id == id);
  }

  /// An id for a newly created transaction.
  String newId() {
    _nextId++;
    return 'txn-${now().microsecondsSinceEpoch}-$_nextId';
  }

  // ------------------------------------------------------------ filtering

  bool _matches(Transaction transaction, TransactionFilter filter) {
    if (filter.type != null && transaction.type != filter.type) return false;

    if (filter.categoryIds.isNotEmpty &&
        !filter.categoryIds.contains(transaction.categoryId)) {
      return false;
    }

    final day = DateLabels.dayOf(transaction.date);
    final from = filter.from;
    final to = filter.to;
    // Both bounds are inclusive, compared at day precision so a
    // transaction recorded at 18:00 is not excluded from a range that
    // ends on its own date.
    if (from != null && day.isBefore(DateLabels.dayOf(from))) return false;
    if (to != null && day.isAfter(DateLabels.dayOf(to))) return false;

    final query = filter.query.trim().toLowerCase();
    if (query.isEmpty) return true;

    // Every word has to appear somewhere, so "food lunch" narrows rather
    // than widening the way an any-word match would.
    return query
        .split(RegExp(r'\s+'))
        .every((word) => transaction.searchHaystack.contains(word));
  }

  /// Newest first, with creation order breaking same-day ties so the list
  /// does not reshuffle between builds.
  static int _newestFirst(Transaction a, Transaction b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  }

  List<TransactionGroup> _group(List<Transaction> sorted) {
    final today = now();
    final groups = <DateTime, List<Transaction>>{};

    for (final transaction in sorted) {
      groups.putIfAbsent(DateLabels.dayOf(transaction.date), () => []).add(
        transaction,
      );
    }

    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days)
        TransactionGroup(
          date: day,
          label: DateLabels.groupLabel(day, today),
          transactions: groups[day]!,
        ),
    ];
  }

  // ---------------------------------------------------- the arithmetic

  /// The sums. Confined to this method, in this file, on purpose.
  TransactionTotals _totals(List<Transaction> matches) {
    var income = 0;
    var expenses = 0;

    for (final transaction in matches) {
      final minorUnits = transaction.amount.minorUnits;
      if (minorUnits >= 0) {
        income += minorUnits;
      } else {
        // Expenses are reported as a positive magnitude, matching the
        // reporting contract where `expense_cents` is positive while the
        // stored amount is negative.
        expenses += -minorUnits;
      }
    }

    return TransactionTotals(
      income: Money(income),
      expenses: Money(expenses),
      net: Money(income - expenses),
      count: matches.length,
    );
  }

  // ----------------------------------------------------------- seed data

  /// Three years of deterministic history.
  ///
  /// Lives in [TransactionHistory] rather than here because reports need
  /// years of it, and three hundred rows inline would bury the repository
  /// they belong to.
  static List<Transaction> _seedFor(DateTime now) =>
      TransactionHistory.generate(now: now);
}
