import 'transaction.dart';

/// What the user has narrowed the list down to.
///
/// One immutable value rather than four separate pieces of state, so the
/// list, the summary and the "clear filters" affordance can never disagree
/// about what is currently applied.
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryIds = const {},
    this.from,
    this.to,
  });

  /// Free text. Matched against description, category label and category id.
  final String query;

  /// Null means both sides of the ledger.
  final TransactionType? type;

  /// Empty means every category.
  final Set<String> categoryIds;

  /// Inclusive date bounds. Null means unbounded on that end.
  final DateTime? from;
  final DateTime? to;

  static const TransactionFilter none = TransactionFilter();

  bool get hasQuery => query.trim().isNotEmpty;

  bool get hasDateRange => from != null || to != null;

  /// Whether anything is narrowing the list.
  ///
  /// The search box is counted separately from the chips: clearing filters
  /// should not silently wipe what someone typed, and the UI treats them
  /// as two different gestures.
  bool get hasFilters =>
      type != null || categoryIds.isNotEmpty || hasDateRange;

  bool get isEmpty => !hasFilters && !hasQuery;

  /// How many filter facets are active, for the badge on the filter button.
  int get activeCount =>
      (type != null ? 1 : 0) +
      (categoryIds.isEmpty ? 0 : 1) +
      (hasDateRange ? 1 : 0);

  TransactionFilter copyWith({
    String? query,
    TransactionType? type,
    bool clearType = false,
    Set<String>? categoryIds,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) => TransactionFilter(
    query: query ?? this.query,
    // Nullable fields cannot be cleared by passing null — that is
    // indistinguishable from "leave alone" — so clearing is explicit.
    type: clearType ? null : (type ?? this.type),
    categoryIds: categoryIds ?? this.categoryIds,
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
  );

  /// Drops the facets but keeps the search text.
  TransactionFilter cleared() => TransactionFilter(query: query);

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.query == query &&
      other.type == type &&
      other.from == from &&
      other.to == to &&
      other.categoryIds.length == categoryIds.length &&
      other.categoryIds.containsAll(categoryIds);

  @override
  int get hashCode => Object.hash(
    query,
    type,
    from,
    to,
    Object.hashAllUnordered(categoryIds),
  );
}
