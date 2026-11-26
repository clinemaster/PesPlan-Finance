import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_result.dart';
import 'package:lifepilot_finance/features/onboarding/domain/country.dart';
import 'package:lifepilot_finance/features/onboarding/domain/user_profile.dart';

void main() {
  group('MockAuthRepository', () {
    test('success returns an identity', () async {
      final repository = MockAuthRepository(delay: Duration.zero);
      final result = await repository.signInWithGoogle();

      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).user, MockAuthRepository.demoUser);
    });

    test('cancel returns AuthCancelled, not an error', () async {
      // The distinction matters all the way up: the welcome screen renders a
      // neutral note for this and a red one for a failure.
      final repository = MockAuthRepository(
        scenario: MockAuthScenario.cancel,
        delay: Duration.zero,
      );

      expect(await repository.signInWithGoogle(), isA<AuthCancelled>());
    });

    test('failure returns a message fit to show a user', () async {
      final repository = MockAuthRepository(
        scenario: MockAuthScenario.failure,
        delay: Duration.zero,
      );

      final result = await repository.signInWithGoogle();
      expect(result, isA<AuthFailed>());
      expect((result as AuthFailed).message, isNotEmpty);
    });

    test('the scenario can be changed between attempts', () async {
      final repository = MockAuthRepository(delay: Duration.zero);
      expect(await repository.signInWithGoogle(), isA<AuthSuccess>());

      repository.scenario = MockAuthScenario.failure;
      expect(await repository.signInWithGoogle(), isA<AuthFailed>());
    });

    test('signOut succeeds and keeps no state', () async {
      final repository = MockAuthRepository(delay: Duration.zero);
      await repository.signInWithGoogle();

      await expectLater(repository.signOut(), completes);
    });
  });

  group('Country catalogue', () {
    test('every country defaults to a currency the app can display', () {
      // The currency dropdown is built from Currency.supported. A country
      // pointing anywhere else would select a value the list cannot show.
      for (final country in Country.supported) {
        expect(
          Currency.supported,
          contains(country.currency),
          reason: '${country.name} defaults to an unsupported currency',
        );
      }
    });

    test('Tanzania leads the list and is the default', () {
      expect(Country.supported.first, Country.tanzania);
      expect(Country.initial, Country.tanzania);
      expect(Country.initial.currency, Currency.tzs);
    });

    test('country codes are unique', () {
      final codes = Country.supported.map((c) => c.code).toSet();
      expect(codes.length, Country.supported.length);
    });
  });

  group('UserProfile', () {
    test('seeds name and email from the identity provider', () {
      final profile = UserProfile.fromAuthUser(MockAuthRepository.demoUser);

      expect(profile.name, MockAuthRepository.demoUser.displayName);
      expect(profile.email, MockAuthRepository.demoUser.email);
      expect(profile.country, Country.tanzania);
      expect(profile.currency, Currency.tzs);
      expect(profile.phone, isNull);
    });

    test('a seeded profile is already complete', () {
      // This is why onboarding can be short: the required answer arrives
      // filled in, and the user only has to agree with it.
      expect(
        UserProfile.fromAuthUser(MockAuthRepository.demoUser).isComplete,
        isTrue,
      );
    });

    test('an empty name makes it incomplete', () {
      final profile = UserProfile.fromAuthUser(
        MockAuthRepository.demoUser,
      ).copyWith(name: '   ');

      expect(profile.isComplete, isFalse);
    });

    test('clearPhone removes a number that copyWith cannot null out', () {
      final withPhone = UserProfile.fromAuthUser(
        MockAuthRepository.demoUser,
      ).copyWith(phone: '+255712345678');
      expect(withPhone.hasPhone, isTrue);

      expect(withPhone.copyWith(clearPhone: true).phone, isNull);
    });

    test('whitespace does not count as a phone number', () {
      final profile = UserProfile.fromAuthUser(
        MockAuthRepository.demoUser,
      ).copyWith(phone: '   ');

      expect(profile.hasPhone, isFalse);
    });
  });
}
