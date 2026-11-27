import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// On the create form the fields are, in order: name, target, already
/// saved, note. The picture is a row of chips and the date is a picker,
/// so neither is a TextField — which is what keeps these indices stable.
Finder get nameField => find.byType(TextField).at(0);
Finder get targetField => find.byType(TextField).at(1);
Finder get initialField => find.byType(TextField).at(2);

/// The note sits below the fold on a phone, so the list has not built it
/// until something scrolls down to it.
Future<void> enterNote(WidgetTester tester, String text) async {
  await scrollToNote(tester);
  await tester.enterText(noteField, text);
  await tester.pumpAndSettle();
}

Future<void> scrollToNote(WidgetTester tester) =>
    SavingsHarness.dragTo(tester, find.text('Note'));

Finder get noteField => find.descendant(
  of: find.ancestor(of: find.text('Note'), matching: find.byType(AppTextField)),
  matching: find.byType(TextField),
);

Future<void> openNewGoal(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Create goal'));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('creating', () {
    testWidgets('a goal appears in the list immediately', (tester) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      expect(find.text('New goal'), findsOneWidget);

      await enter(tester, nameField, 'Business capital');
      await enter(tester, targetField, '3000000');
      await tapText(tester, 'Business');
      await enterNote(tester, 'Stock for the shop');
      await tapText(tester, 'Create goal');

      expect(harness.savings.allGoals, hasLength(1));
      final saved = harness.savings.allGoals.single;
      expect(saved.name, 'Business capital');
      expect(saved.target.minorUnits, 3000000);
      expect(saved.iconKey, 'business');
      expect(saved.description, 'Stock for the shop');

      expect(find.text('Business capital'), findsOneWidget);
      expect(find.text('TSh 0 of TSh 3,000,000'), findsOneWidget);
      expect(find.text('TSh 3,000,000 to go'), findsOneWidget);
    });

    testWidgets('an opening amount is recorded as history, not a field', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'New laptop');
      await enter(tester, targetField, '1500000');
      await enter(tester, initialField, '200000');
      await tapText(tester, 'Create goal');

      expect(harness.savings.allMovements, hasLength(1));
      expect(harness.savings.allMovements.single.isContribution, isTrue);
      expect(find.text('TSh 200,000 of TSh 1,500,000'), findsOneWidget);
    });

    testWidgets('confirms the save and returns to the list', (tester) async {
      await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'Travel');
      await enter(tester, targetField, '600000');
      await tapText(tester, 'Create goal');

      expect(find.text('Goal created'), findsOneWidget);
      expect(find.text('New goal'), findsNothing);
    });

    testWidgets('a goal starts at zero, with no history', (tester) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'School fees');
      await enter(tester, targetField, '900000');
      await tapText(tester, 'Create goal');
      await tapText(tester, 'School fees');

      expect(harness.savings.allMovements, isEmpty);
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('the first goal replaces the empty state', (tester) async {
      await SavingsHarness.pump(tester, goals: const []);
      expect(find.text('No savings goals yet.'), findsOneWidget);

      await tapText(tester, 'Create goal');
      await enter(tester, nameField, 'Emergency fund');
      await enter(tester, targetField, '2000000');
      await tapText(tester, 'Create goal');

      expect(find.text('No savings goals yet.'), findsNothing);
      expect(find.text('Set aside'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('a nameless goal is refused, and nothing is saved', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, targetField, '500000');
      await tapText(tester, 'Create goal');

      expect(find.text('Give this goal a name'), findsOneWidget);
      expect(harness.savings.allGoals, isEmpty);
    });

    testWidgets('a goal with no target is refused', (tester) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'Something');
      await tapText(tester, 'Create goal');

      expect(find.text('Enter a target amount'), findsOneWidget);
      expect(harness.savings.allGoals, isEmpty);
    });

    testWidgets('a target of zero is refused', (tester) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'Something');
      await enter(tester, targetField, '0');
      await tapText(tester, 'Create goal');

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(harness.savings.allGoals, isEmpty);
    });

    testWidgets('an opening amount above the target is refused', (
      tester,
    ) async {
      // A goal created already finished is a completion the app never saw
      // happen, with no history behind it.
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'New laptop');
      await enter(tester, targetField, '500000');
      await enter(tester, initialField, '900000');
      await tapText(tester, 'Create goal');

      expect(find.text('That is more than the target'), findsOneWidget);
      expect(harness.savings.allGoals, isEmpty);
    });

    testWidgets('a note past the cap is refused', (tester) async {
      final harness = await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, nameField, 'Something');
      await enter(tester, targetField, '500000');
      await enterNote(tester, 'x' * 200);
      await tapText(tester, 'Create goal');

      expect(find.textContaining('Keep it under'), findsOneWidget);
      expect(harness.savings.allGoals, isEmpty);
    });

    testWidgets('fixing the problem clears the message', (tester) async {
      await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      await enter(tester, targetField, '500000');
      await tapText(tester, 'Create goal');
      expect(find.text('Give this goal a name'), findsOneWidget);

      await enter(tester, nameField, 'Emergency fund');
      expect(find.text('Give this goal a name'), findsNothing);
    });

    testWidgets('errors appear only once the user has tried to save', (
      tester,
    ) async {
      // A form that is red before it has been touched reads as broken.
      await SavingsHarness.pump(tester, goals: const []);
      await openNewGoal(tester);

      expect(find.text('Give this goal a name'), findsNothing);
      expect(find.text('Enter a target amount'), findsNothing);
    });
  });

  group('editing', () {
    Future<void> openEditor(WidgetTester tester, String name) async {
      await tapText(tester, name);
      // Edit and Delete sit below the history, which grows — so the
      // detail screen is dragged to them rather than assumed visible.
      await SavingsHarness.dragTo(
        tester,
        find.widgetWithText(AppButton, 'Edit'),
      );
      await tapText(tester, 'Edit');
    }

    testWidgets('the form opens pre-filled, without an amount box', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(target: 500000, name: 'Emergency fund', description: 'Buffer'),
        ],
        movements: [paidIn(amount: 100000)],
      );
      await openEditor(tester, 'Emergency fund');

      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text('Emergency fund'), findsWidgets);
      expect(find.text('500000'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      await scrollToNote(tester);
      expect(find.text('Buffer'), findsOneWidget);
      // An existing goal's balance is its movements; an "already saved"
      // box here would look like a way to overwrite them.
      expect(find.text('Already saved'), findsNothing);
    });

    testWidgets('a new name and target are stored, and history is kept', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000, description: 'First month')],
      );

      await openEditor(tester, 'Emergency fund');
      await enter(tester, nameField, 'Rainy day fund');
      await enter(tester, targetField, '800000');
      await tapText(tester, 'Save changes');

      expect(find.text('Goal updated'), findsOneWidget);
      expect(harness.savings.allGoals.single.name, 'Rainy day fund');
      expect(harness.savings.allGoals.single.target.minorUnits, 800000);
      expect(harness.savings.allMovements, hasLength(1));
      expect(find.text('First month'), findsOneWidget);

      // The detail screen kept the offset it had when Edit was opened,
      // so the summary is back up at the top.
      await SavingsHarness.scrollToTop(tester);
      expect(find.text('TSh 700,000 to go'), findsWidgets);
    });

    testWidgets('changing the picture keeps everything else', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000)],
      );

      await openEditor(tester, 'Emergency fund');
      await tapText(tester, 'Travel');
      await tapText(tester, 'Save changes');

      expect(harness.savings.allGoals.single.iconKey, 'travel');
      expect(harness.savings.allGoals.single.target.minorUnits, 500000);
    });

    testWidgets('lowering the target below what is saved warns first', (
      tester,
    ) async {
      // A user correcting a typo should not be surprised by a completion.
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 900000, name: 'Emergency fund')],
        movements: [paidIn(amount: 500000)],
      );

      await openEditor(tester, 'Emergency fund');
      await enter(tester, targetField, '400000');

      expect(
        find.textContaining('will mark the goal complete'),
        findsOneWidget,
      );
    });

    testWidgets('and then completes the goal, keeping the movements', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 900000, name: 'Emergency fund')],
        movements: [
          paidIn(id: 'a', amount: 300000),
          paidIn(id: 'b', amount: 200000),
        ],
      );

      await openEditor(tester, 'Emergency fund');
      await enter(tester, targetField, '400000');
      await tapText(tester, 'Save changes');

      // Back on the goal, which now reads as finished — and still holds
      // everything that was put into it. Asserted on the breakdown
      // rather than the card at the top, which the screen scrolled past
      // on the way to the Edit button.
      expect(harness.savings.allMovements, hasLength(2));
      expect(find.text('2 movements'), findsOneWidget);
      expect(find.text('TSh 400,000'), findsOneWidget);
      expect(find.text('TSh 0'), findsOneWidget);

      // And it has moved into the finished section of the list.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await SavingsHarness.scrollTo(tester, find.text('Reached'));

      expect(find.text('Reached'), findsOneWidget);
      expect(find.text('Target reached'), findsOneWidget);
    });

    testWidgets('a goal that is gone says so instead of failing', (
      tester,
    ) async {
      // Delete sits beside Edit on the detail screen, so this is a real
      // case rather than a defensive branch.
      await SavingsHarness.pump(
        tester,
        route: Routes.goalEdit('no-such-goal'),
        goals: const [],
      );

      expect(find.text('That goal is gone'), findsOneWidget);
      expect(find.text('Back to goals'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks first, naming the goal and what it holds', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000)],
      );

      await tapText(tester, 'Emergency fund');
      await SavingsHarness.dragTo(
        tester,
        find.widgetWithText(AppButton, 'Delete'),
      );
      await tapText(tester, 'Delete');

      expect(find.text('Delete this goal?'), findsOneWidget);
      expect(
        find.textContaining('Emergency fund and its 1 recorded'),
        findsOneWidget,
      );
      expect(harness.savings.allGoals, hasLength(1));
    });

    testWidgets('cancelling keeps it', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000)],
      );

      await tapText(tester, 'Emergency fund');
      await SavingsHarness.dragTo(
        tester,
        find.widgetWithText(AppButton, 'Delete'),
      );
      await tapText(tester, 'Delete');
      await tapText(tester, 'Cancel');

      expect(harness.savings.allGoals, hasLength(1));
    });

    testWidgets('confirming removes the goal and its history', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [
          goal(target: 500000, id: 'a', name: 'Emergency fund'),
          goal(target: 300000, id: 'b', name: 'New laptop'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'a', amount: 100000),
          paidIn(id: 'm2', goalId: 'b', amount: 50000),
        ],
      );

      await tapText(tester, 'Emergency fund');
      await SavingsHarness.dragTo(
        tester,
        find.widgetWithText(AppButton, 'Delete'),
      );
      await tapText(tester, 'Delete');
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(harness.savings.allGoals.map((g) => g.id), ['b']);
      expect(harness.savings.allMovements.map((m) => m.id), ['m2']);
      expect(find.text('Goal deleted'), findsOneWidget);
      expect(find.text('Emergency fund'), findsNothing);
      expect(find.text('New laptop'), findsOneWidget);
    });

    testWidgets('deleting the last one leaves the empty state, not zeroes', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: const [],
      );

      await tapText(tester, 'Emergency fund');
      await SavingsHarness.dragTo(
        tester,
        find.widgetWithText(AppButton, 'Delete'),
      );
      await tapText(tester, 'Delete');
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(harness.savings.allGoals, isEmpty);
      expect(find.text('No savings goals yet.'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', SavingsHarness.phone),
      ('a small phone', SavingsHarness.smallPhone),
    ]) {
      testWidgets('the form fits $name', (tester) async {
        await SavingsHarness.pump(tester, size: size, goals: const []);
        await openNewGoal(tester);
        await scrollToNote(tester);

        expect(tester.takeException(), isNull);
      });

      testWidgets('the detail screen fits $name', (tester) async {
        await SavingsHarness.pump(
          tester,
          size: size,
          goals: [
            goal(
              target: 2000000,
              name: 'Emergency fund',
              description: 'A note long enough to wrap onto a second line',
              targetDate: DateTime(2027, 6, 30),
            ),
          ],
          movements: [
            paidIn(id: 'a', amount: 300000, description: 'First month'),
            tookOut(id: 'b', amount: 50000, description: 'Hospital deposit'),
          ],
        );
        await tapText(tester, 'Emergency fund');
        await SavingsHarness.scrollTo(
          tester,
          find.widgetWithText(AppButton, 'Delete'),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
