import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/widgets/brand_mark.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/widgets/google_sign_in_button.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('shows the brand, the promise and one way in', (tester) async {
      await OnboardingHarness.pump(tester);

      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.text('LifePilot'), findsOneWidget);
      expect(find.text(WelcomeScreen.tagline), findsOneWidget);
      expect(find.text(WelcomeScreen.intro), findsOneWidget);
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('offers terms and privacy', (tester) async {
      await OnboardingHarness.pump(tester);

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('the privacy note states that no Google service is called', (
      tester,
    ) async {
      // The claim this phase has to be able to make, made where a reviewer
      // can read it.
      await OnboardingHarness.pump(tester);

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('contacts no Google service'),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner while signing in', (tester) async {
      final harness = await OnboardingHarness.pump(
        tester,
        authDelay: const Duration(milliseconds: 500),
      );

      await tester.tap(find.text('Continue with Google'));
      // The first pump builds the loading tree and starts the cross-fade;
      // the second advances past it, so the outgoing label has left the
      // tree. Both are well short of the 500ms sign-in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(harness.authState, isA<AuthInProgress>());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('the button ignores a second tap while in flight', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(
        tester,
        authDelay: const Duration(milliseconds: 500),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GoogleSignInButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // One attempt, one result: a second sign-in would have overwritten
      // the first and could land after it.
      expect(harness.authState, isA<AuthAuthenticated>());
    });

    testWidgets('a cancelled sign-in reads as a choice, not a failure', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(
        tester,
        scenario: MockAuthScenario.cancel,
      );

      await harness.signIn(tester);

      expect(harness.authState, isA<AuthDismissed>());
      expect(find.textContaining('Sign-in cancelled'), findsOneWidget);
      // Still on welcome, still able to try again.
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('a failed sign-in shows the provider message', (tester) async {
      final harness = await OnboardingHarness.pump(
        tester,
        scenario: MockAuthScenario.failure,
      );

      await harness.signIn(tester);

      expect(harness.authState, isA<AuthErrored>());
      expect(find.textContaining('Could not reach Google'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('retrying after a failure can succeed', (tester) async {
      final harness = await OnboardingHarness.pump(
        tester,
        scenario: MockAuthScenario.failure,
      );
      await harness.signIn(tester);
      expect(harness.authState, isA<AuthErrored>());

      harness.container
          .read(mockAuthScenarioProvider.notifier)
          .select(MockAuthScenario.success);
      await harness.signIn(tester);

      expect(harness.authState, isA<AuthAuthenticated>());
    });
  });
}
