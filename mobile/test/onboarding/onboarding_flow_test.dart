import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/domain/country.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// The name field is the first TextField on the profile step; the phone
/// field is the second. The email between them is not a TextField at all —
/// it is a read-only surface — which is what keeps these indices stable.
final Finder nameField = find.byType(TextField).at(0);
final Finder phoneField = find.byType(TextField).at(1);

void main() {
  group('sign-in hands over to onboarding', () {
    testWidgets('a successful sign-in lands on the profile step', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      expect(find.text('About you'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('the profile step arrives pre-filled from the provider', (
      tester,
    ) async {
      // The reason this flow is two screens instead of a registration form.
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      expect(find.text(MockAuthRepository.demoUser.displayName), findsOneWidget);
      expect(find.text(MockAuthRepository.demoUser.email), findsOneWidget);
    });

    testWidgets('the email is presented as read-only', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      expect(find.text('From your Google account'), findsOneWidget);
      // Name and phone are editable; the email is not one of them.
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('a cancelled sign-in stays on welcome', (tester) async {
      final harness = await OnboardingHarness.pump(
        tester,
        scenario: MockAuthScenario.cancel,
      );
      await harness.signIn(tester);

      expect(find.text('About you'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('an empty name blocks the step and explains why', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(nameField, '');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('About you'), findsOneWidget);
      expect(find.textContaining('Enter your name'), findsOneWidget);
    });

    testWidgets('no error is shown before the first attempt', (tester) async {
      // Telling someone they are wrong before they have touched the field is
      // how a two-screen flow starts feeling like a form.
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter your name'), findsNothing);
    });

    testWidgets('the error clears as soon as the name is fixed', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(nameField, '');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter your name'), findsOneWidget);

      await tester.enterText(nameField, 'Juma');
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter your name'), findsNothing);
    });

    testWidgets('a malformed phone blocks the step', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(phoneField, 'call me');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('About you'), findsOneWidget);
      expect(find.textContaining('digits only'), findsOneWidget);
    });

    testWidgets('a valid phone is accepted', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(phoneField, '+255 712 345 678');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your preferences'), findsOneWidget);
      expect(
        harness.onboarding.draft!.phone,
        '+255 712 345 678',
      );
    });

    testWidgets('the phone can be skipped entirely', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your preferences'), findsOneWidget);
      expect(harness.onboarding.draft!.hasPhone, isFalse);
    });
  });

  group('preferences', () {
    testWidgets('opens with the launch market selected', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachPreferences(tester);

      expect(find.text('Tanzania'), findsOneWidget);
      expect(harness.onboarding.draft!.currency, Currency.tzs);
    });

    testWidgets('choosing a country moves the currency with it', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachPreferences(tester);

      await tester.tap(find.text('Tanzania'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Germany').last);
      await tester.pumpAndSettle();

      expect(harness.onboarding.draft!.country, Country.germany);
      expect(harness.onboarding.draft!.currency, Currency.eur);
    });

    testWidgets('language can be changed to Kiswahili', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachPreferences(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiswahili').last);
      await tester.pumpAndSettle();

      expect(harness.onboarding.draft!.language.code, 'sw');
    });

    testWidgets('the language note does not promise a translated UI', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachPreferences(tester);

      expect(find.textContaining('English only for now'), findsOneWidget);
    });
  });

  group('completion', () {
    testWidgets('summarises what was collected', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);

      expect(find.textContaining('You are all set'), findsOneWidget);
      expect(find.text(MockAuthRepository.demoUser.email), findsOneWidget);
      expect(find.text('Tanzania'), findsOneWidget);
    });

    testWidgets('a skipped phone is shown as absent, not blank', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);

      expect(find.text('Not added'), findsOneWidget);
    });

    testWidgets('finishing enters the app', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);

      await tester.tap(find.text('Start using LifePilot'));
      await tester.pumpAndSettle();

      expect(harness.onboarding.completed, isTrue);
      expect(find.textContaining('Welcome, Amina'), findsOneWidget);
      expect(find.text('You are all set, Amina'), findsNothing);
    });

    testWidgets('onboarding cannot be re-entered once finished', (
      tester,
    ) async {
      // The guard, not the screens, is what enforces this.
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);
      await tester.tap(find.text('Start using LifePilot'));
      await tester.pumpAndSettle();

      expect(find.text('About you'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });
  });

  group('back navigation', () {
    testWidgets('preferences goes back to the profile step', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachPreferences(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('About you'), findsOneWidget);
    });

    testWidgets('an edit made before going back survives', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.enterText(nameField, 'Juma Mushi');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(harness.onboarding.draft!.name, 'Juma Mushi');
      expect(find.text('Juma Mushi'), findsOneWidget);
    });

    testWidgets('completion goes back to preferences', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Your preferences'), findsOneWidget);
    });

    testWidgets('a summary row jumps back to the step that owns it', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);

      // The summary is six rows; on the 800x600 test surface the lower ones
      // start below the fold.
      await tester.ensureVisible(find.byTooltip('Edit Country'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Country'));
      await tester.pumpAndSettle();

      expect(find.text('Your preferences'), findsOneWidget);
    });

    testWidgets('leaving the first step asks before discarding sign-in', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.tap(find.byTooltip('Leave setup'));
      await tester.pumpAndSettle();
      expect(find.text('Leave setup?'), findsOneWidget);

      await tester.tap(find.text('Keep setting up'));
      await tester.pumpAndSettle();

      expect(find.text('About you'), findsOneWidget);
    });

    testWidgets('confirming the exit signs out and returns to welcome', (
      tester,
    ) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.signIn(tester);

      await tester.tap(find.byTooltip('Leave setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(harness.onboarding.hasDraft, isFalse);
    });
  });

  group('signing out of the app', () {
    testWidgets('returns to welcome with the draft cleared', (tester) async {
      final harness = await OnboardingHarness.pump(tester);
      await harness.reachCompletion(tester);
      await tester.tap(find.text('Start using LifePilot'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(harness.onboarding.hasDraft, isFalse);
      expect(harness.onboarding.completed, isFalse);
    });
  });
}
