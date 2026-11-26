import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';

/// Boots the real app — real router, real providers — with only the auth
/// repository swapped.
///
/// Testing through [LifePilotApp] rather than mounting screens directly is
/// what makes these tests worth having: the redirect guard, the provider
/// wiring and the screens are exercised together, which is where this
/// feature's actual behaviour lives. A test that pumps `ProfileSetupScreen`
/// on its own would pass even if the router never routed to it.
class OnboardingHarness {
  OnboardingHarness._(this.container);

  final ProviderContainer container;

  /// How long the fake provider sheet takes.
  ///
  /// Zero for tests that only care about the outcome. A real duration for
  /// the loading-state test, which needs a window in which the spinner is
  /// on screen.
  static Future<OnboardingHarness> pump(
    WidgetTester tester, {
    MockAuthScenario scenario = MockAuthScenario.success,
    Duration authDelay = Duration.zero,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(scenario: scenario, delay: authDelay),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mockAuthScenarioProvider.notifier).select(scenario);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LifePilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    return OnboardingHarness._(container);
  }

  AuthState get authState => container.read(authControllerProvider);

  OnboardingState get onboarding => container.read(onboardingControllerProvider);

  /// Taps "Continue with Google" and lets the flow settle.
  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  /// Signs in and walks to the preferences step.
  Future<void> reachPreferences(WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  /// Signs in and walks to the review step.
  Future<void> reachCompletion(WidgetTester tester) async {
    await reachPreferences(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
}
