import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../data/mock_transaction_repository.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_repository.dart';
import '../../domain/transaction_view.dart';

/// Where transactions live.
///
/// Phase 05 binds this to the in-memory mock. Phase 13 overrides it with an
/// API-backed repository; nothing above this line changes.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => MockTransactionRepository(now: ref.watch(clockProvider)),
);

/// What the user has narrowed the list to.
class TransactionFilterController extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.none;

  void setQuery(String query) => state = state.copyWith(query: query);

  void clearQuery() => state = state.copyWith(query: '');

  /// Tapping the active type chip again turns it off, which is what people
  /// expect from a toggle and saves a trip to the filter sheet to undo.
  void toggleType(TransactionType type) => state = state.type == type
      ? state.copyWith(clearType: true)
      : state.copyWith(type: type);

  void setType(TransactionType? type) => state = type == null
      ? state.copyWith(clearType: true)
      : state.copyWith(type: type);

  void toggleCategory(String categoryId) {
    final next = {...state.categoryIds};
    if (!next.remove(categoryId)) next.add(categoryId);
    state = state.copyWith(categoryIds: next);
  }

  void setCategories(Set<String> categoryIds) =>
      state = state.copyWith(categoryIds: categoryIds);

  void setDateRange({DateTime? from, DateTime? to}) => from == null && to == null
      ? state = state.copyWith(clearDates: true)
      : state = state.copyWith(from: from, to: to);

  void clearDateRange() => state = state.copyWith(clearDates: true);

  /// Drops the facets but keeps what the user typed — clearing filters and
  /// clearing a search are two different intentions.
  void clearFilters() => state = state.cleared();

  void reset() => state = TransactionFilter.none;
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterController, TransactionFilter>(
      TransactionFilterController.new,
    );

/// The list, filtered, grouped and totalled by the repository.
///
/// One provider for the whole screen: the groups, the summary and the
/// result counts all come from the same snapshot, so they cannot disagree
/// about what is currently shown.
final transactionListProvider = FutureProvider<TransactionListView>((
  ref,
) async {
  final filter = ref.watch(transactionFilterProvider);
  return ref.read(transactionRepositoryProvider).list(filter);
});

/// One transaction, for the detail sheet and the edit form.
final transactionByIdProvider = FutureProvider.family<Transaction?, String>((
  ref,
  id,
) async {
  // Depends on the list so a write refreshes an open detail view rather
  // than leaving it showing the previous values.
  ref.watch(transactionListProvider);
  return ref.read(transactionRepositoryProvider).byId(id);
});

/// Writes, plus the one thing every write has in common: the list has to
/// be rebuilt afterwards.
///
/// A plain object rather than a Notifier because there is no state to
/// hold — the form screens own their own saving flag, since that is a
/// property of the screen rather than of the data.
class TransactionActions {
  const TransactionActions(this._ref);

  final Ref _ref;

  TransactionRepository get _repository =>
      _ref.read(transactionRepositoryProvider);

  /// An id for a new transaction. Only the mock mints ids; a real backend
  /// assigns them, which is why this is not part of the interface.
  String newId() {
    final repository = _repository;
    return repository is MockTransactionRepository
        ? repository.newId()
        : DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<Transaction> add(Transaction transaction) async {
    final saved = await _repository.add(transaction);
    _invalidate();
    return saved;
  }

  Future<Transaction> update(Transaction transaction) async {
    final saved = await _repository.update(transaction);
    _invalidate();
    return saved;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _invalidate();
  }

  void _invalidate() => _ref.invalidate(transactionListProvider);
}

final transactionActionsProvider = Provider<TransactionActions>(
  TransactionActions.new,
);
