import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/onboarding/domain/profile_validator.dart';

void main() {
  group('name validation', () {
    test('accepts an ordinary name', () {
      expect(ProfileValidator.name('Amina Hassan'), isNull);
    });

    test('accepts names with marks and non-Latin scripts', () {
      // The letter check uses a Unicode property, not A-Z. Getting this
      // wrong would reject a large share of the launch market's names.
      expect(ProfileValidator.name('Zoë'), isNull);
      expect(ProfileValidator.name('Søren'), isNull);
      expect(ProfileValidator.name('李雷'), isNull);
    });

    test('rejects empty and whitespace-only input', () {
      expect(ProfileValidator.name(''), isNotNull);
      expect(ProfileValidator.name(null), isNotNull);
      expect(ProfileValidator.name('   '), isNotNull);
    });

    test('rejects a single character', () {
      expect(ProfileValidator.name('A'), isNotNull);
    });

    test('rejects input with no letter at all', () {
      // The field arrives pre-filled and then gets edited, so "123" is a
      // realistic way to end up with a technically-non-empty name.
      expect(ProfileValidator.name('123'), isNotNull);
      expect(ProfileValidator.name('...'), isNotNull);
    });

    test('rejects a name past the length limit', () {
      expect(ProfileValidator.name('a' * 61), isNotNull);
      expect(ProfileValidator.name('a' * 60), isNull);
    });

    test('measures length after trimming', () {
      expect(ProfileValidator.name('  Jo  '), isNull);
    });
  });

  group('phone validation', () {
    test('empty is valid, because the field is optional', () {
      // The flow promises this field can be skipped. A validator that
      // disagreed would strand the user on a screen whose Continue never
      // enables.
      expect(ProfileValidator.phone(''), isNull);
      expect(ProfileValidator.phone(null), isNull);
      expect(ProfileValidator.phone('   '), isNull);
    });

    test('accepts a Tanzanian number in the formats people type', () {
      expect(ProfileValidator.phone('+255712345678'), isNull);
      expect(ProfileValidator.phone('+255 712 345 678'), isNull);
      expect(ProfileValidator.phone('0712-345-678'), isNull);
      expect(ProfileValidator.phone('(0712) 345 678'), isNull);
    });

    test('accepts international numbers', () {
      expect(ProfileValidator.phone('+44 20 7946 0958'), isNull);
      expect(ProfileValidator.phone('+1 415 555 2671'), isNull);
    });

    test('rejects letters', () {
      expect(ProfileValidator.phone('call me'), isNotNull);
      expect(ProfileValidator.phone('+255 712 ABC 678'), isNotNull);
    });

    test('rejects numbers outside plausible length', () {
      expect(ProfileValidator.phone('12345'), isNotNull);
      expect(ProfileValidator.phone('1234567890123456'), isNotNull);
    });

    test('a plus is only allowed at the front', () {
      expect(ProfileValidator.phone('255+712345678'), isNotNull);
    });
  });

  group('canSubmitProfile', () {
    test('passes with a valid name and no phone', () {
      expect(
        ProfileValidator.canSubmitProfile(name: 'Amina', phone: null),
        isTrue,
      );
    });

    test('passes with a valid name and a valid phone', () {
      expect(
        ProfileValidator.canSubmitProfile(
          name: 'Amina',
          phone: '+255712345678',
        ),
        isTrue,
      );
    });

    test('fails on a bad name even when the phone is fine', () {
      expect(
        ProfileValidator.canSubmitProfile(name: '', phone: '+255712345678'),
        isFalse,
      );
    });

    test('fails on a bad phone even when the name is fine', () {
      expect(
        ProfileValidator.canSubmitProfile(name: 'Amina', phone: 'nope'),
        isFalse,
      );
    });
  });
}
