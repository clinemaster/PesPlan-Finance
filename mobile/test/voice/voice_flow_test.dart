import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/voice/data/mock_voice_repository.dart';
import 'package:lifepilot_finance/features/voice/presentation/widgets/voice_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('the screen it opens on', () {
    testWidgets('asks the question and offers the microphone', (tester) async {
      await VoiceHarness.pump(tester);

      expect(find.text('What did you spend or earn?'), findsOneWidget);
      expect(
        find.text("Just say it naturally. We'll help organise it."),
        findsOneWidget,
      );
      expect(find.byType(MicButton), findsOneWidget);
      expect(find.text('Tap to start'), findsOneWidget);
    });

    testWidgets('shows what to say, in both languages', (tester) async {
      await VoiceHarness.pump(tester);

      expect(find.text('Try saying'), findsOneWidget);
      expect(find.text('Kiswahili'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
    });

    testWidgets('the examples follow the language chosen', (tester) async {
      await VoiceHarness.pump(tester);

      await tester.tap(find.text('Kiswahili'));
      await tester.pumpAndSettle();
      expect(
        find.text('“Nimetumia shilingi elfu kumi kwa chakula.”'),
        findsOneWidget,
      );
      expect(
        find.text('Sema kwa Kiswahili — kama unavyozungumza.'),
        findsOneWidget,
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        find.text('“I spent ten thousand shillings on food.”'),
        findsOneWidget,
      );
    });

    testWidgets('offers typing instead, and goes there', (tester) async {
      // A voice feature that corners someone into using it is worse than
      // no voice feature.
      await VoiceHarness.pump(tester);
      await VoiceHarness.dragTo(
        tester,
        find.text('Enter transaction manually'),
      );

      await tester.tap(find.text('Enter transaction manually'));
      await tester.pumpAndSettle();

      expect(find.text('New transaction'), findsOneWidget);
    });
  });

  group('recording', () {
    testWidgets('says it is listening, and counts', (tester) async {
      await VoiceHarness.pump(tester);

      await VoiceHarness.tapMic(tester);

      expect(find.text('Listening…'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:03'), findsOneWidget);

      // Leave nothing running behind the test.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('says it in Kiswahili when that is the language', (
      tester,
    ) async {
      await VoiceHarness.pump(tester);
      await tester.tap(find.text('Kiswahili'));
      await tester.pumpAndSettle();

      await VoiceHarness.tapMic(tester);

      expect(find.text('Ninasikiliza…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('offers stop and cancel, and nothing else', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.tapMic(tester);

      expect(find.text('Stop and continue'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Try saying'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling goes back to the start with nothing kept', (
      tester,
    ) async {
      final harness = await VoiceHarness.pump(tester);

      await VoiceHarness.tapMic(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('What did you spend or earn?'), findsOneWidget);
      expect(find.text('Tap to start'), findsOneWidget);
      expect(harness.transactions.all, isEmpty);
    });

    testWidgets('the microphone pulses only while listening', (tester) async {
      // Run with animations on, which is the default on a device without
      // the reduced-motion setting.
      await VoiceHarness.pump(tester, animations: true);

      expect(tester.binding.transientCallbackCount, 0);

      await VoiceHarness.tapMic(tester);
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the ring should be animating while the mic is open',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('reduced motion stops the pulse entirely', (tester) async {
      // A ring that breathes forever costs battery and attention; a
      // device that asks for less motion gets none.
      await VoiceHarness.pump(tester);

      await VoiceHarness.tapMic(tester);

      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('Listening…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('understanding', () {
    testWidgets('shows what it heard, and in which language', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speak(tester);

      expect(find.text('What we heard'), findsOneWidget);
      expect(
        find.text('“Nimetumia shilingi elfu kumi kwa chakula”'),
        findsOneWidget,
      );
      expect(find.text('Kiswahili'), findsOneWidget);
    });

    testWidgets('says plainly that nothing has been saved yet', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speak(tester);

      expect(find.textContaining('Nothing is saved yet'), findsOneWidget);
    });

    testWidgets('a two-tap recording is told it heard nothing', (tester) async {
      // Opening and closing the microphone has heard nothing, and saying
      // so is more honest than inventing a sentence.
      await VoiceHarness.pump(tester);

      await VoiceHarness.tapMic(tester);
      await tester.tap(find.text('Stop and continue'));
      await tester.pumpAndSettle();

      expect(find.text('We did not catch that'), findsOneWidget);
      expect(find.textContaining('too short'), findsOneWidget);
    });

    testWidgets('a failure is friendly, and offers both ways out', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, scenario: VoiceScenario.failure);
      await VoiceHarness.speak(tester);

      expect(find.text('We did not catch that'), findsOneWidget);
      expect(find.textContaining("couldn't make out"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Enter transaction manually'), findsOneWidget);
      // "Try again" with a plus on it says the wrong thing.
      expect(
        find.descendant(
          of: find.widgetWithText(AppButton, 'Try again'),
          matching: find.byIcon(AppIcons.refresh),
        ),
        findsOneWidget,
      );
    });

    testWidgets('trying again returns to a clean microphone', (tester) async {
      await VoiceHarness.pump(tester, scenario: VoiceScenario.failure);
      await VoiceHarness.speak(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to start'), findsOneWidget);
    });
  });

  group('correcting what was heard', () {
    testWidgets('the text can be edited and re-read', (tester) async {
      // The one thing that step exists for: a correction has to change
      // the figures, or it is decoration.
      await VoiceHarness.pump(tester);
      await VoiceHarness.speak(tester);

      await tester.tap(find.text('Edit text'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Nimetumia elfu ishirini kwa nauli',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();

      expect(find.text('Your correction'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('TSh 20,000'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
    });

    testWidgets('discarding an edit keeps what was heard', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speak(tester);

      await tester.tap(find.text('Edit text'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'something else');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('What we heard'), findsOneWidget);
      expect(
        find.text('“Nimetumia shilingi elfu kumi kwa chakula”'),
        findsOneWidget,
      );
    });

    testWidgets('try again throws the attempt away', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speak(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to start'), findsOneWidget);
      expect(find.text('What we heard'), findsNothing);
    });
  });

  group('the review', () {
    testWidgets('shows every field it understood', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      expect(
        find.textContaining('Please review your transaction before saving'),
        findsOneWidget,
      );
      expect(find.text('Out'), findsOneWidget);
      expect(find.text('TSh 10,000'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('26 November 2026'), findsOneWidget);
      expect(find.text('Chakula'), findsOneWidget);
      expect(find.text('TZS'), findsOneWidget);
      // An optional field nobody mentioned is not a failure to hear.
      expect(find.text('Not heard'), findsNothing);
    });

    testWidgets('income is shown as money in', (tester) async {
      await VoiceHarness.pump(tester, scenario: VoiceScenario.clearIncome);
      await VoiceHarness.speakAndContinue(tester);

      expect(find.text('In'), findsOneWidget);
      expect(find.text('TSh 1,000,000'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);

      // The user's own word becomes the note: "mshahara" says more in
      // the list than "Salary", which the category already says.
      await VoiceHarness.dragTo(tester, find.text('Description'));
      expect(find.text('Mshahara'), findsOneWidget);
      expect(find.text('Not heard'), findsNothing);
    });

    testWidgets('an optional field nobody filled reads as none', (
      tester,
    ) async {
      // In English the spoken word is "salary", which only repeats the
      // category — so there is no note, and an empty optional field is
      // not a failure to hear.
      await VoiceHarness.pump(tester, scenario: VoiceScenario.clearIncome);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      await VoiceHarness.speakAndContinue(tester);
      await VoiceHarness.dragTo(tester, find.text('Description'));

      expect(
        find.text('“I received one million shillings as salary”'),
        findsOneWidget,
      );
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Not heard'), findsNothing);
    });

    testWidgets('it can go back to the transcript', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      await VoiceHarness.dragTo(tester, find.text('Back to what you said'));
      await tester.tap(find.text('Back to what you said'));
      await tester.pumpAndSettle();

      expect(find.text('Edit text'), findsOneWidget);
    });

    testWidgets('cancelling leaves without saving anything', (tester) async {
      final harness = await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.transactions.all, isEmpty);
      expect(find.text('What did you spend or earn?'), findsNothing);
    });
  });

  group('uncertainty', () {
    testWidgets('an amount that was not heard is asked for, not invented', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, scenario: VoiceScenario.missingAmount);
      await VoiceHarness.speakAndContinue(tester);

      expect(find.text('Not heard'), findsWidgets);
      expect(
        find.textContaining("couldn't confidently identify the amount"),
        findsOneWidget,
      );
    });

    testWidgets('and the save is replaced by a way to fill it in', (
      tester,
    ) async {
      final harness = await VoiceHarness.pump(
        tester,
        scenario: VoiceScenario.missingAmount,
      );
      await VoiceHarness.speakAndContinue(tester);

      expect(find.text('Confirm & save'), findsNothing);
      expect(find.text('Add the missing details'), findsOneWidget);
      // And not a second button going to the same place.
      expect(find.text('Edit details'), findsNothing);
      expect(harness.transactions.all, isEmpty);
    });

    testWidgets('filling it in opens the form with what was understood', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, scenario: VoiceScenario.missingAmount);
      await VoiceHarness.speakAndContinue(tester);

      await tester.tap(find.text('Add the missing details'));
      await tester.pumpAndSettle();

      expect(find.text('New transaction'), findsOneWidget);
      // The category it did hear is already chosen, so the user fills in
      // the one thing that was missing.
      expect(find.text('Bills'), findsWidgets);
    });

    testWidgets('a complete extraction is not marked for review', (
      tester,
    ) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      expect(find.text('Not heard'), findsNothing);
      expect(find.textContaining("couldn't"), findsNothing);
      expect(find.text('Confirm & save'), findsOneWidget);
    });
  });

  group('confirming', () {
    testWidgets('saves exactly what was on the card', (tester) async {
      final harness = await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      await tester.tap(find.text('Confirm & save'));
      await tester.pumpAndSettle();

      expect(harness.transactions.all, hasLength(1));
      final saved = harness.transactions.all.single;
      expect(saved.type, TransactionType.expense);
      expect(saved.amount.minorUnits, -10000);
      expect(saved.categoryId, 'food');
      expect(saved.description, 'Chakula');
      expect(saved.date, DateTime(2026, 11, 26));
    });

    testWidgets('confirms it and returns to where the user came from', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, route: Routes.home, seed: null);

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();
      await VoiceHarness.speakAndContinue(tester);
      await tester.tap(find.text('Confirm & save'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction saved'), findsOneWidget);
      expect(find.textContaining('Good afternoon, Amina'), findsOneWidget);
    });

    testWidgets('the saved transaction shows up in the list', (tester) async {
      await VoiceHarness.pump(tester, route: Routes.home, seed: null);

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();
      await VoiceHarness.speakAndContinue(tester);
      await tester.tap(find.text('Confirm & save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Chakula'), findsOneWidget);
      expect(find.text('-TSh 10,000'), findsWidgets);
    });

    testWidgets('an income saves on the right side of the ledger', (
      tester,
    ) async {
      final harness = await VoiceHarness.pump(
        tester,
        scenario: VoiceScenario.clearIncome,
      );
      await VoiceHarness.speakAndContinue(tester);
      await tester.tap(find.text('Confirm & save'));
      await tester.pumpAndSettle();

      expect(harness.transactions.all.single.amount.minorUnits, 1000000);
    });

    testWidgets('nothing is saved before the user confirms', (tester) async {
      // The rule the whole screen is built around.
      final harness = await VoiceHarness.pump(tester);

      await VoiceHarness.speak(tester);
      expect(harness.transactions.all, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(harness.transactions.all, isEmpty);
    });
  });

  group('editing before saving', () {
    testWidgets('opens the Phase 05 form, filled in', (tester) async {
      await VoiceHarness.pump(tester);
      await VoiceHarness.speakAndContinue(tester);

      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();

      expect(find.text('New transaction'), findsOneWidget);
      expect(find.text('10000'), findsOneWidget);
      expect(find.text('Chakula'), findsOneWidget);
    });

    testWidgets('and saving there records it once', (tester) async {
      // The voice screen is replaced rather than left underneath, so the
      // same transaction cannot be saved twice.
      final harness = await VoiceHarness.pump(
        tester,
        route: Routes.home,
        seed: null,
      );

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();
      await VoiceHarness.speakAndContinue(tester);
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '12500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      // One record, not two: the voice screen was replaced rather than
      // left under the form, so there is no review to come back to and
      // confirm a second time.
      final spoken = harness.transactions.all
          .where((t) => t.description == 'Chakula')
          .toList();
      expect(spoken, hasLength(1));
      expect(spoken.single.amount.minorUnits, -12500);
      expect(find.textContaining('Good afternoon, Amina'), findsOneWidget);
    });
  });

  group('the way in', () {
    testWidgets('the dashboard quick action opens it', (tester) async {
      await VoiceHarness.pump(tester, route: Routes.home, seed: null);

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();

      expect(find.text('What did you spend or earn?'), findsOneWidget);
    });

    testWidgets('the transaction form offers it, and hands over', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, route: Routes.transactionNew);
      await VoiceHarness.dragTo(tester, find.text('Say it instead'));

      await tester.tap(find.text('Say it instead'));
      await tester.pumpAndSettle();

      expect(find.text('What did you spend or earn?'), findsOneWidget);
    });

    testWidgets('leaving by the back button clears the attempt', (
      tester,
    ) async {
      await VoiceHarness.pump(tester, route: Routes.home, seed: null);
      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();
      await VoiceHarness.speak(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to start'), findsOneWidget);
      expect(find.text('What we heard'), findsNothing);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', VoiceHarness.phone),
      ('a small phone', VoiceHarness.smallPhone),
    ]) {
      testWidgets('the opening screen fits $name', (tester) async {
        await VoiceHarness.pump(tester, size: size);
        await VoiceHarness.dragTo(
          tester,
          find.text('Enter transaction manually'),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('recording fits $name', (tester) async {
        await VoiceHarness.pump(tester, size: size);
        await VoiceHarness.tapMic(tester);
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets('the review fits $name', (tester) async {
        await VoiceHarness.pump(
          tester,
          size: size,
          scenario: VoiceScenario.missingAmount,
        );
        await VoiceHarness.speakAndContinue(tester);
        await VoiceHarness.dragTo(tester, find.text('Back to what you said'));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
