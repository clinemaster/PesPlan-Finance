import 'transaction.dart';
import 'transaction_filter.dart';
import 'transaction_view.dart';

/// Where transactions live.
///
/// The screen asks for a [TransactionListView] — already filtered, already
/// grouped, already totalled — rather than a raw list it would have to
/// process itself. That keeps the grouping rules and the arithmetic on the
/// far side of this boundary, which is where they belong and where Phase 13
/// will put them on a server.
abstract interface class TransactionRepository {
  /// The list, narrowed by [filter].
  Future<TransactionListView> list(TransactionFilter filter);

  /// One transaction, or null if it is gone.
  Future<Transaction?> byId(String id);

  /// Stores a new transaction and returns it as stored.
  Future<Transaction> add(Transaction transaction);

  /// Replaces an existing transaction, matched on id.
  Future<Transaction> update(Transaction transaction);

  Future<void> delete(String id);
}
