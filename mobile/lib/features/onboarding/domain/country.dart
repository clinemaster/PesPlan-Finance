import '../../../core/money/money.dart';

/// A country a user can onboard from.
///
/// Each entry carries the currency that country actually uses, so selecting a
/// country can pre-fill the currency field instead of asking the user a
/// question they have already answered. The user can still override it — a
/// Tanzanian who budgets in USD is a real case, not a mistake.
///
/// Every [currency] here must be one of [Currency.supported], otherwise the
/// currency dropdown would be handed a value it cannot display. A test pins
/// that invariant.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.currency,
  });

  /// ISO 3166-1 alpha-2.
  final String code;

  final String name;

  /// E.164 calling prefix, shown beside the phone field so the user knows
  /// what format is expected.
  final String dialCode;

  /// The currency pre-selected when this country is chosen.
  final Currency currency;

  static const Country tanzania = Country(
    code: 'TZ',
    name: 'Tanzania',
    dialCode: '+255',
    currency: Currency.tzs,
  );

  static const Country kenya = Country(
    code: 'KE',
    name: 'Kenya',
    dialCode: '+254',
    currency: Currency.kes,
  );

  static const Country unitedStates = Country(
    code: 'US',
    name: 'United States',
    dialCode: '+1',
    currency: Currency.usd,
  );

  static const Country unitedKingdom = Country(
    code: 'GB',
    name: 'United Kingdom',
    dialCode: '+44',
    currency: Currency.gbp,
  );

  static const Country germany = Country(
    code: 'DE',
    name: 'Germany',
    dialCode: '+49',
    currency: Currency.eur,
  );

  /// Tanzania leads because it is the launch market, and a list that opens on
  /// the answer most users want is faster than an alphabetical one they have
  /// to scroll. The rest are alphabetical so the ordering is not arbitrary.
  static const List<Country> supported = [
    tanzania,
    germany,
    kenya,
    unitedKingdom,
    unitedStates,
  ];

  /// The market the app ships into first, and the default selection.
  static const Country initial = tanzania;

  @override
  bool operator ==(Object other) => other is Country && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
