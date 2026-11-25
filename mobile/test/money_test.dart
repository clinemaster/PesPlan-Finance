import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';

void main() {
  group('Money formatting', () {
    test('TZS renders whole shillings with no decimal part', () {
      // The point of the zero-decimal currency: "TSh 12,500.00" would be wrong
      // for Tanzania, and this is the test that keeps it that way.
      expect(const Money(12500).format(), 'TSh 12,500');
      expect(const Money(2450000).format(), 'TSh 2,450,000');
    });

    test('two-decimal currencies render a fraction', () {
      expect(
        const Money(123456, currency: Currency.usd).format(),
        r'$1,234.56',
      );
      expect(const Money(5, currency: Currency.usd).format(), r'$0.05');
      expect(const Money(100, currency: Currency.usd).format(), r'$1.00');
    });

    test('negative amounts put the sign before the symbol', () {
      expect(const Money(-85400).format(), '-TSh 85,400');
      expect(const Money(-1234, currency: Currency.usd).format(), r'-$12.34');
    });

    test('showSign adds a plus to positive values but not to zero', () {
      expect(const Money(5000).format(showSign: true), '+TSh 5,000');
      expect(const Money(0).format(showSign: true), 'TSh 0');
      expect(const Money(-5000).format(showSign: true), '-TSh 5,000');
    });

    test('showSymbol can be suppressed', () {
      expect(const Money(12500).format(showSymbol: false), '12,500');
    });

    test('thousands grouping handles every digit-count boundary', () {
      expect(const Money(1).format(showSymbol: false), '1');
      expect(const Money(999).format(showSymbol: false), '999');
      expect(const Money(1000).format(showSymbol: false), '1,000');
      expect(const Money(10000).format(showSymbol: false), '10,000');
      expect(const Money(100000).format(showSymbol: false), '100,000');
      expect(const Money(1000000).format(showSymbol: false), '1,000,000');
    });

    test('abbreviate is compact, for axis ticks only', () {
      expect(const Money(0).format(abbreviate: true), 'TSh 0');
      expect(const Money(950).format(abbreviate: true), 'TSh 950');
      expect(const Money(1500).format(abbreviate: true), 'TSh 1.5K');
      expect(const Money(12000).format(abbreviate: true), 'TSh 12K');
      expect(const Money(1875500).format(abbreviate: true), 'TSh 1.9M');
      expect(const Money(2000000000).format(abbreviate: true), 'TSh 2B');
    });

    test('abbreviate accounts for the currency scale', () {
      // 150000 cents is 1,500 dollars -> 1.5K, not 150K.
      expect(
        const Money(150000, currency: Currency.usd).format(abbreviate: true),
        r'$1.5K',
      );
    });
  });

  group('Money semantics', () {
    test('spells out currency and direction for screen readers', () {
      expect(const Money(12500).semanticLabel, '12,500 TZS in');
      expect(const Money(-12500).semanticLabel, '12,500 TZS out');
      expect(const Money(0).semanticLabel, '0 TZS');
    });

    test('direction flags match the sign convention', () {
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(1).isNegative, isFalse);
      expect(const Money(0).isZero, isTrue);
    });
  });

  group('Money has no arithmetic', () {
    // There is no test that calls `money + money`, because the API
    // deliberately does not expose one: every total comes from the backend
    // (architecture Rule 1). This test documents the contract so a future
    // "convenience" operator has to argue with a failing expectation.
    test('exposes only value and formatting members', () {
      const money = Money(1000);
      expect(money.minorUnits, 1000);
      expect(money.currency, Currency.tzs);
      expect(money.format(), isA<String>());
      expect(money.semanticLabel, isA<String>());
    });
  });

  group('Currency', () {
    test('TZS is the launch default and has no subunit', () {
      expect(const Money(1).currency, Currency.tzs);
      expect(Currency.tzs.decimalDigits, 0);
      expect(Currency.tzs.symbol, 'TSh');
    });

    test('equality is by ISO code', () {
      expect(
        Currency.tzs,
        const Currency(code: 'TZS', symbol: 'whatever', decimalDigits: 9),
      );
      expect(Currency.tzs == Currency.usd, isFalse);
    });

    test('supported list leads with the launch market', () {
      expect(Currency.supported.first, Currency.tzs);
      expect(Currency.supported, contains(Currency.usd));
    });
  });
}
