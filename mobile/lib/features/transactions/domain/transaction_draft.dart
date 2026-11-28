import 'transaction.dart';

/// A transaction that is not finished yet.
///
/// Every field is optional, which is the point: a draft comes from
/// somewhere that may not know all of them — voice today, a shared
/// receipt or an SMS later — and the form fills in the rest. A
/// [Transaction] is a record of something that happened; this is what is
/// known so far.
class TransactionDraft {
  const TransactionDraft({
    this.type,
    this.magnitudeMinorUnits,
    this.categoryId,
    this.categoryLabel,
    this.date,
    this.description = '',
  });

  /// Which side of the ledger, when that is known.
  final TransactionType? type;

  /// Always a positive magnitude. The type carries the sign, exactly as
  /// it does on the form — a draft never holds a signed amount, so there
  /// is no second place for the sign convention to be got wrong.
  final int? magnitudeMinorUnits;

  final String? categoryId;
  final String? categoryLabel;
  final DateTime? date;
  final String description;

  bool get hasAmount => magnitudeMinorUnits != null;

  bool get hasCategory => (categoryId ?? '').isNotEmpty;

  /// Whether this could be saved without anyone filling anything in.
  bool get isComplete => type != null && hasAmount && hasCategory;

  TransactionDraft copyWith({
    TransactionType? type,
    int? magnitudeMinorUnits,
    bool clearAmount = false,
    String? categoryId,
    String? categoryLabel,
    bool clearCategory = false,
    DateTime? date,
    String? description,
  }) => TransactionDraft(
    type: type ?? this.type,
    magnitudeMinorUnits: clearAmount
        ? null
        : (magnitudeMinorUnits ?? this.magnitudeMinorUnits),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    categoryLabel: clearCategory ? null : (categoryLabel ?? this.categoryLabel),
    date: date ?? this.date,
    description: description ?? this.description,
  );

  @override
  String toString() =>
      'TransactionDraft(${type?.name}, $magnitudeMinorUnits, $categoryId)';
}
