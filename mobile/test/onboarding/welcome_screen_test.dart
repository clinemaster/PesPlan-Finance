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

      expect(find.textContaining('contacts no Google service'), findsOneWidget);
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

  group('saying which provider this is', () {
    testWidgets('a demo build admits it under the button', (tester) async {
      // The button carries Google's name and mark. Someone tapping it
      // reasonably believes they are handing over a Google account, and on
      // this build they are not.
      await OnboardingHarness.pump(tester);

      expect(find.textContaining('Demo sign-in'), findsOneWidget);
    });

    testWidgets('a configured build says nothing of the sort', (tester) async {
      await OnboardingHarness.pump(
        tester,
        config: OnboardingHarness.googleConfigured,
      );

      expect(find.textContaining('Demo sign-in'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('the privacy note drops the mock claim once configured', (
      tester,
    ) async {
      // A stale "no Google service is contacted" in a privacy note is the
      // worst place in the app to leave a sentence that has become untrue.
      await OnboardingHarness.pump(
        tester,
        config: OnboardingHarness.googleConfigured,
      );

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('contacts no Google service'), findsNothing);
      expect(find.textContaining('asks Google who you are'), findsOneWidget);
    });

    testWidgets('the review menu exists only while the mock does', (
      tester,
    ) async {
      await OnboardingHarness.pump(tester);

      await tester.longPress(find.byType(BrandMark));
      await tester.pumpAndSettle();

      expect(find.text('Mock sign-in outcome'), findsOneWidget);
      expect(find.text('Succeed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Fail'), findsOneWidget);
    });

    testWidgets('and is gone on a configured build', (tester) async {
      // There is nothing to choose: the provider decides what happens.
      await OnboardingHarness.pump(
        tester,
        config: OnboardingHarness.googleConfigured,
      );

      await tester.longPress(find.byType(BrandMark));
      await tester.pumpAndSettle();

      expect(find.text('Mock sign-in outcome'), findsNothing);
    });

    testWidgets('the demo note fits a small phone', (tester) async {
      // It is an extra two lines on the tightest screen the app supports,
      // on a layout held apart by Spacers.
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await OnboardingHarness.pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Demo sign-in'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
