/// Money for display.
///
/// ## The rule this file exists to enforce
///
/// LifePilot has exactly one financial engine, and it is the Python backend
/// (`docs/PROPOSED_SYSTEM_ARCHITECTURE.md`, Rule 1). The app formats figures;
/// it never computes them. So [Money] carries an integer minor-unit amount
/// and knows how to render it — and deliberately has **no `+`, `-`, `*` or
/// `/` operator**. A developer who tries to total a list of amounts on the
/// client finds no API to do it with, which is the point.
///
/// Amounts are integer **minor units** (cents, or whole shillings where the
/// currency has no subunit), matching the backend's `*_cents` contract
/// (Rule 2). `double` is never used for money: binary floating point cannot
/// represent 0.10 exactly, and a cent of drift in a ledger is a defect.
library;

/// A currency, with the formatting facts the UI needs.
///
/// Tanzania ships first, so TZS is the default — and TZS matters here beyond
/// the symbol: the shilling is quoted in **whole units**, so [decimalDigits]
/// is 0. An app that renders "TSh 12,500.00" looks like it was localised by
/// someone who has never seen a Tanzanian price tag.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.decimalDigits,
    this.symbolOnLeft = true,
    this.spaceBetweenSymbolAndAmount = true,
  });

  /// ISO 4217 code, e.g. `TZS`.
  final String code;

  /// Display symbol, e.g. `TSh`.
  final String symbol;

  /// Fractional digits: 0 for TZS, 2 for USD and EUR.
  final int decimalDigits;

  final bool symbolOnLeft;
  final bool spaceBetweenSymbolAndAmount;

  /// Tanzanian shilling — the launch currency. No subunit in practice.
  static const Currency tzs = Currency(
    code: 'TZS',
    symbol: 'TSh',
    decimalDigits: 0,
  );

  static const Currency kes = Currency(
    code: 'KES',
    symbol: 'KSh',
    decimalDigits: 2,
  );

  static const Currency usd = Currency(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
    spaceBetweenSymbolAndAmount: false,
  );

  static const Currency eur = Currency(
    code: 'EUR',
    symbol: '€',
    decimalDigits: 2,
    spaceBetweenSymbolAndAmount: false,
  );

  static const Currency gbp = Currency(
    code: 'GBP',
    symbol: '£',
    decimalDigits: 2,
    spaceBetweenSymbolAndAmount: false,
  );

  /// The currencies offered at launch. Extending this list is the whole
  /// extent of adding a currency to the UI.
  static const List<Currency> supported = [tzs, kes, usd, eur, gbp];

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// An amount in integer minor units, plus its currency.
class Money {
  const Money(this.minorUnits, {this.currency = Currency.tzs});

  /// Cents, or whole shillings for a zero-decimal currency. Negative means
  /// money out, positive money in — the backend's sign convention.
  final int minorUnits;

  final Currency currency;

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;

  /// Format for display.
  ///
  /// [showSign] forces a leading `+` on positive values, useful in a list
  /// that mixes income and expenses.
  /// [showSymbol] can be turned off where a column header already names the
  /// currency.
  /// [abbreviate] renders large figures compactly (`1.2M`) for chart ticks —
  /// never for a figure the user may need exactly.
  String format({
    bool showSymbol = true,
    bool showSign = false,
    bool abbreviate = false,
  }) {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();

    final String body;
    if (abbreviate) {
      body = _abbreviate(absolute);
    } else {
      final divisor = _pow10(currency.decimalDigits);
      final whole = absolute ~/ divisor;
      final grouped = _group(whole);
      if (currency.decimalDigits == 0) {
        body = grouped;
      } else {
        final fraction = (absolute % divisor).toString().padLeft(
          currency.decimalDigits,
          '0',
        );
        body = '$grouped.$fraction';
      }
    }

    final sign = negative ? '-' : (showSign && !isZero ? '+' : '');

    if (!showSymbol) return '$sign$body';

    final gap = currency.spaceBetweenSymbolAndAmount ? ' ' : '';
    return currency.symbolOnLeft
        ? '$sign${currency.symbol}$gap$body'
        : '$sign$body$gap${currency.symbol}';
  }

  /// A screen-reader friendly rendering.
  ///
  /// "-TSh 12,500" is read by TalkBack as a run of characters that can be
  /// ambiguous; this spells out the direction and the currency instead, so a
  /// user hears "12,500 Tanzanian shillings out" rather than a symbol salad.
  String get semanticLabel {
    final amount = Money(
      minorUnits.abs(),
      currency: currency,
    ).format(showSymbol: false);
    final direction = isZero ? '' : (isNegative ? ' out' : ' in');
    return '$amount ${currency.code}$direction';
  }

  @override
  String toString() => format();

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// Thousands separators, inserted without touching the value.
  static String _group(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final leading = digits.length % 3;
    if (leading > 0) buffer.write(digits.substring(0, leading));
    for (var i = leading; i < digits.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write(',');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }

  /// Compact form, for axis ticks only.
  String _abbreviate(int absoluteMinor) {
    final units = absoluteMinor / _pow10(currency.decimalDigits);
    if (units >= 1000000000) return '${_trim(units / 1000000000)}B';
    if (units >= 1000000) return '${_trim(units / 1000000)}M';
    if (units >= 1000) return '${_trim(units / 1000)}K';
    return _group(units.round());
  }

  static String _trim(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}
