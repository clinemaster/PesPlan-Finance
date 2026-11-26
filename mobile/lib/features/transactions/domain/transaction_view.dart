import '../../../core/money/money.dart';
import 'transaction.dart';

/// One day's transactions, under a heading.
///
/// Grouping by day is what turns a list into something scannable: people
/// remember "I think that was Tuesday" far better than they remember a
/// position in a list, and the heading gives the eye somewhere to stop.
class TransactionGroup {
  const TransactionGroup({
    required this.date,
    required this.label,
    required this.transactions,
  });

  /// Midnight on the day this group covers.
  final DateTime date;

  /// "Today", "Yesterday" or "23 November 2026".
  final String label;

  final List<Transaction> transactions;
}

/// Totals for whatever is currently on screen.
///
/// ## These arrive computed, they are not derived here
///
/// Architecture Rule 1: the app has no financial engine. This class is a
/// container for three figures the repository produced — it does no
/// arithmetic of its own, and neither does anything that displays it.
///
/// While the data is mocked, the repository plays the part of the server
/// and does the summing. When Phase 13 replaces it, these come off the
/// wire instead and nothing above this line changes.
class TransactionTotals {
  const TransactionTotals({
    required this.income,
    required this.expenses,
    required this.net,
    required this.count,
  });

  static const TransactionTotals zero = TransactionTotals(
    income: Money(0),
    expenses: Money(0),
    net: Money(0),
    count: 0,
  );

  /// Money in over the listed set.
  final Money income;

  /// Money out, as a positive magnitude.
  final Money expenses;

  /// Income minus expenses.
  final Money net;

  /// How many transactions the totals cover.
  final int count;
}

/// Everything one render of the transactions screen needs.
class TransactionListView {
  const TransactionListView({
    required this.groups,
    required this.totals,
    required this.matchCount,
    required this.totalCount,
  });

  static const TransactionListView empty = TransactionListView(
    groups: [],
    totals: TransactionTotals.zero,
    matchCount: 0,
    totalCount: 0,
  );

  final List<TransactionGroup> groups;
  final TransactionTotals totals;

  /// How many transactions survived the filter.
  final int matchCount;

  /// How many exist in total, filter ignored.
  ///
  /// The two together are what let the screen tell "you have nothing
  /// recorded" apart from "nothing matches what you asked for" — which
  /// need completely different words and a different way out.
  final int totalCount;

  bool get hasResults => matchCount > 0;

  /// True when the account itself is empty, rather than the filter being
  /// too narrow.
  bool get isAccountEmpty => totalCount == 0;
}
