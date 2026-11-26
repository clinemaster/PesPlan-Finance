import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/domain/app_language.dart';
import 'package:lifepilot_finance/features/onboarding/domain/country.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';

/// A container with the auth repository swapped for an instant mock.
ProviderContainer makeContainer({
  MockAuthScenario scenario = MockAuthScenario.success,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(scenario: scenario, delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(mockAuthScenarioProvider.notifier).select(scenario);
  return container;
}

void main() {
  group('AuthController', () {
    test('starts idle', () {
      expect(makeContainer().read(authControllerProvider), isA<AuthIdle>());
    });

    test('a successful sign-in ends authenticated', () async {
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, MockAuthRepository.demoUser);
    });

    test('a cancelled sign-in is dismissed, not errored', () async {
      final container = makeContainer(scenario: MockAuthScenario.cancel);
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(authControllerProvider), isA<AuthDismissed>());
      expect(container.read(currentUserProvider), isNull);
    });

    test('a failed sign-in carries a message', () async {
      final container = makeContainer(scenario: MockAuthScenario.failure);
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthErrored>());
      expect((state as AuthErrored).message, isNotEmpty);
    });

    test('acknowledge clears a dismissal back to idle', () async {
      final container = makeContainer(scenario: MockAuthScenario.cancel);
      final controller = container.read(authControllerProvider.notifier);

      await controller.signInWithGoogle();
      controller.acknowledge();

      expect(container.read(authControllerProvider), isA<AuthIdle>());
    });

    test('acknowledge leaves an authenticated session alone', () async {
      final container = makeContainer();
      final controller = container.read(authControllerProvider.notifier);

      await controller.signInWithGoogle();
      controller.acknowledge();

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });

    test('signing out clears the user', () async {
      final container = makeContainer();
      final controller = container.read(authControllerProvider.notifier);

      await controller.signInWithGoogle();
      await controller.signOut();

      expect(container.read(currentUserProvider), isNull);
    });
  });

  group('OnboardingController', () {
    test('has no draft before sign-in', () {
      final state = makeContainer().read(onboardingControllerProvider);
      expect(state.hasDraft, isFalse);
      expect(state.completed, isFalse);
    });

    test('signing in seeds a draft from the identity', () async {
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final draft = container.read(onboardingControllerProvider).draft;
      expect(draft, isNotNull);
      expect(draft!.name, MockAuthRepository.demoUser.displayName);
      expect(draft.email, MockAuthRepository.demoUser.email);
    });

    Future<ProviderContainer> signedIn() async {
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).signInWithGoogle();
      return container;
    }

    test('editing the name is kept', () async {
      final container = await signedIn();
      container.read(onboardingControllerProvider.notifier).updateName('Juma');

      expect(container.read(onboardingControllerProvider).draft!.name, 'Juma');
    });

    test('choosing a country moves the currency with it', () async {
      // Leaving TZS selected after someone picks Germany is a quiet way to
      // get the wrong currency onto an account.
      final container = await signedIn();
      container
          .read(onboardingControllerProvider.notifier)
          .updateCountry(Country.germany);

      final draft = container.read(onboardingControllerProvider).draft!;
      expect(draft.country, Country.germany);
      expect(draft.currency, Currency.eur);
    });

    test('currency can still be overridden after a country choice', () async {
      final container = await signedIn();
      final controller = container.read(onboardingControllerProvider.notifier);

      controller
        ..updateCountry(Country.germany)
        ..updateCurrency(Currency.usd);

      final draft = container.read(onboardingControllerProvider).draft!;
      expect(draft.country, Country.germany);
      expect(draft.currency, Currency.usd);
    });

    test('language is recorded', () async {
      final container = await signedIn();
      container
          .read(onboardingControllerProvider.notifier)
          .updateLanguage(AppLanguage.swahili);

      expect(
        container.read(onboardingControllerProvider).draft!.language,
        AppLanguage.swahili,
      );
    });

    test('an empty phone clears the field rather than storing a blank', () async {
      final container = await signedIn();
      final controller = container.read(onboardingControllerProvider.notifier);

      controller.updatePhone('+255712345678');
      expect(container.read(onboardingControllerProvider).draft!.hasPhone, isTrue);

      controller.updatePhone('   ');
      expect(container.read(onboardingControllerProvider).draft!.phone, isNull);
    });

    test('complete() is refused while the name is invalid', () async {
      // The router advances on `completed`, so a controller that let this
      // through would put a user into the app with a blank profile.
      final container = await signedIn();
      final controller = container.read(onboardingControllerProvider.notifier);

      controller.updateName('');
      controller.complete();

      expect(container.read(onboardingControllerProvider).completed, isFalse);
    });

    test('complete() succeeds with a valid draft', () async {
      final container = await signedIn();
      container.read(onboardingControllerProvider.notifier).complete();

      expect(container.read(onboardingControllerProvider).completed, isTrue);
    });

    test('reset clears the draft', () async {
      final container = await signedIn();
      final controller = container.read(onboardingControllerProvider.notifier);

      controller
        ..complete()
        ..reset();

      final state = container.read(onboardingControllerProvider);
      expect(state.hasDraft, isFalse);
      expect(state.completed, isFalse);
    });

    test('a cancelled sign-in produces no draft', () async {
      final container = makeContainer(scenario: MockAuthScenario.cancel);
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(onboardingControllerProvider).hasDraft, isFalse);
    });
  });
}
