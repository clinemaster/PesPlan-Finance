import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/savings/presentation/widgets/savings_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

Finder get amountField => find.byType(TextField).first;

Future<void> openGoal(WidgetTester tester, [String name = 'Emergency fund']) =>
    tapText(tester, name);

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> addMoney(
  WidgetTester tester,
  String amount, {
  String? note,
}) async {
  await tapText(tester, 'Add money');
  await enter(tester, amountField, amount);
  if (note != null) {
    await SavingsHarness.dragTo(tester, find.text('Note'));
    await tester.enterText(find.byType(TextField).last, note);
    await tester.pumpAndSettle();
  }
  await tapText(tester, 'Add to goal');
}

Future<void> takeOut(WidgetTester tester, String amount) async {
  await tapText(tester, 'Take out');
  await enter(tester, amountField, amount);
  await tapText(tester, 'Take out');
}

void main() {
  group('the detail screen', () {
    testWidgets('breaks one goal down', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(
            target: 2000000,
            name: 'Emergency fund',
            description: 'Three months of essentials',
            targetDate: DateTime(2027, 6, 30),
          ),
        ],
        movements: [
          paidIn(id: 'a', amount: 600000),
          tookOut(id: 'b', amount: 50000),
          paidIn(id: 'c', amount: 300000, day: 20),
        ],
      );
      await openGoal(tester);

      expect(find.text('Saved so far'), findsOneWidget);
      expect(find.text('TSh 850,000'), findsWidgets);
      expect(find.text('of TSh 2,000,000'), findsOneWidget);

      await SavingsHarness.dragTo(tester, find.text('Started'));

      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('TSh 1,150,000'), findsOneWidget);
      expect(find.text('Put in'), findsOneWidget);
      expect(find.text('TSh 900,000'), findsOneWidget);
      expect(find.text('Taken out'), findsOneWidget);
      expect(find.text('TSh 50,000'), findsWidgets);
      expect(find.text('Time left'), findsOneWidget);
      expect(find.text('Three months of essentials'), findsOneWidget);
    });

    testWidgets('says plainly when there is no target date', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );
      await openGoal(tester);
      await SavingsHarness.dragTo(tester, find.text('Target date'));

      expect(find.text('No date set'), findsOneWidget);
      expect(find.text('Time left'), findsNothing);
    });

    testWidgets('hides the taken-out row when nothing came back out', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );
      await openGoal(tester);
      await SavingsHarness.dragTo(tester, find.text('Put in'));

      expect(find.text('Taken out'), findsNothing);
    });
  });

  group('history', () {
    testWidgets('lists movements newest first, both ways', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 100000, day: 2, description: 'First month'),
          tookOut(id: 'b', amount: 30000, day: 14, description: 'Taxi home'),
          paidIn(id: 'c', amount: 60000, day: 24, description: 'Payday'),
        ],
      );
      await openGoal(tester);
      await SavingsHarness.dragTo(tester, find.text('History'));

      expect(find.text('3 movements'), findsOneWidget);

      final rows = tester
          .widgetList<MovementRow>(find.byType(MovementRow))
          .map((row) => row.movement.id)
          .toList();
      expect(rows, ['c', 'b', 'a']);
    });

    testWidgets('shows the kind, the date and a signed amount', (tester) async {
      // Direction is carried by the words and the sign, not by colour
      // alone — roughly one man in twelve cannot separate the two hues.
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 100000, day: 2, description: 'First month'),
          tookOut(id: 'b', amount: 30000, day: 14),
        ],
      );
      await openGoal(tester);
      await SavingsHarness.dragTo(tester, find.text('History'));

      expect(find.text('First month'), findsOneWidget);
      expect(find.text('+TSh 100,000'), findsOneWidget);
      // One with a note keeps the kind on its second line, where that is
      // the only place saying which way the money went in words.
      expect(find.text('Contribution · 2 Nov'), findsOneWidget);

      // One without a note is titled by its kind, so the second line is
      // the date alone rather than "Withdrawal · Withdrawal · 14 Nov".
      expect(find.text('Withdrawal'), findsOneWidget);
      expect(find.text('14 Nov'), findsOneWidget);
      expect(find.text('−TSh 30,000'), findsOneWidget);
    });

    testWidgets('a goal with nothing recorded says so', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );
      await openGoal(tester);
      await SavingsHarness.dragTo(tester, find.text('History'));

      expect(find.text('Nothing recorded yet'), findsOneWidget);
      expect(find.byType(MovementRow), findsNothing);
    });
  });

  group('adding money', () {
    testWidgets('moves the balance, the bar and the history at once', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );
      await openGoal(tester);
      await addMoney(tester, '150000', note: 'Payday');

      expect(harness.savings.allMovements, hasLength(2));
      expect(find.text('TSh 250,000'), findsWidgets);
      expect(find.textContaining('Added to Emergency fund'), findsOneWidget);

      await SavingsHarness.dragTo(tester, find.text('History'));
      expect(find.text('Payday'), findsOneWidget);
      expect(find.text('+TSh 150,000'), findsOneWidget);
    });

    testWidgets('states what the goal holds before anything is typed', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );
      await openGoal(tester);
      await tapText(tester, 'Add money');

      expect(find.text('Add money'), findsWidgets);
      expect(find.text('TSh 100,000 of TSh 500,000 saved'), findsOneWidget);
    });

    testWidgets('an empty amount is refused, and nothing is recorded', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );
      await openGoal(tester);
      await tapText(tester, 'Add money');
      await tapText(tester, 'Add to goal');

      expect(find.text('Enter an amount'), findsOneWidget);
      expect(harness.savings.allMovements, isEmpty);
    });

    testWidgets('zero is refused', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );
      await openGoal(tester);
      await tapText(tester, 'Add money');
      await enter(tester, amountField, '0');
      await tapText(tester, 'Add to goal');

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(harness.savings.allMovements, isEmpty);
    });

    testWidgets('reaching the target completes the goal', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 400000)],
      );
      await openGoal(tester);
      await addMoney(tester, '100000');

      expect(find.textContaining('Target reached. You saved'), findsOneWidget);
      expect(harness.savings.allMovements, hasLength(2));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await SavingsHarness.scrollTo(tester, find.text('Reached'));
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('saving past the target is allowed and reported honestly', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 400000)],
      );
      await openGoal(tester);
      await addMoney(tester, '200000');

      expect(find.text('TSh 600,000'), findsWidgets);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await SavingsHarness.scrollTo(tester, find.text('Reached'));

      // The card caps the bar at full, and the figures stay true.
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('TSh 600,000 of TSh 500,000'), findsOneWidget);
    });
  });

  group('taking money out', () {
    testWidgets('lowers the balance and is recorded as a withdrawal', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 200000)],
      );
      await openGoal(tester);
      await takeOut(tester, '50000');

      expect(harness.savings.allMovements, hasLength(2));
      expect(harness.savings.allMovements.last.isContribution, isFalse);
      expect(find.text('TSh 150,000'), findsWidgets);
      expect(
        find.textContaining('Taken out of Emergency fund'),
        findsOneWidget,
      );
    });

    testWidgets('more than the goal holds is refused', (tester) async {
      // The money was never there to take, so there is no state in which
      // this is a withdrawal rather than a mistake.
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 200000)],
      );
      await openGoal(tester);
      await tapText(tester, 'Take out');
      await enter(tester, amountField, '250000');
      await tapText(tester, 'Take out');

      expect(find.text('That is more than this goal holds'), findsOneWidget);
      expect(harness.savings.allMovements, hasLength(1));
    });

    testWidgets('exactly the balance is allowed, and leaves nothing', (
      tester,
    ) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 200000)],
      );
      await openGoal(tester);
      await takeOut(tester, '200000');

      expect(harness.savings.allMovements, hasLength(2));
      expect(find.text('TSh 0'), findsWidgets);
      expect(find.text('TSh 500,000 to go'), findsWidgets);
    });

    testWidgets('states what is available before anything is typed', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 200000)],
      );
      await openGoal(tester);
      await tapText(tester, 'Take out');

      expect(find.text('TSh 200,000 available'), findsOneWidget);
      expect(
        find.textContaining('lowers what this goal holds'),
        findsOneWidget,
      );
    });

    testWidgets('an empty goal offers nothing to take', (tester) async {
      // Disabled rather than hidden, so the action stays where the user
      // learned it was.
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );
      await openGoal(tester);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Take out'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a withdrawal can un-complete a goal', (tester) async {
      // The state follows the money: a goal that was finished and then
      // raided is a goal being saved toward again.
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 500000)],
      );
      await openGoal(tester);
      await takeOut(tester, '100000');

      expect(find.textContaining('Target reached'), findsNothing);
      expect(find.text('TSh 100,000 to go'), findsOneWidget);
    });
  });

  group('savings are not transactions', () {
    testWidgets('a contribution does not appear in the transaction list', (
      tester,
    ) async {
      // The rule this phase turns on: setting money aside is not
      // spending it. If a contribution reached the transaction
      // repository, every report in the app would overstate spending.
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );
      await openGoal(tester);
      await addMoney(tester, '150000', note: 'Set aside today');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Set aside today'), findsNothing);
      expect(harness.savings.allMovements, hasLength(1));
    });

    testWidgets('and does not move the dashboard figures', (tester) async {
      final harness = await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: const [],
      );

      final before = harness.container
          .read(dashboardProvider)
          .value!
          .expenses
          .minorUnits;

      await openGoal(tester);
      await addMoney(tester, '150000');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      final after = harness.container
          .read(dashboardProvider)
          .value!
          .expenses
          .minorUnits;

      expect(after, before, reason: 'saving is not spending');
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', SavingsHarness.phone),
      ('a small phone', SavingsHarness.smallPhone),
    ]) {
      testWidgets('neither action label is truncated on $name', (tester) async {
        // "Add money" took twice the width at first, which squeezed the
        // other button into "Take…" — an ellipsis is not an overflow, so
        // only looking at the screen caught it.
        await SavingsHarness.pump(
          tester,
          size: size,
          goals: [goal(target: 500000)],
          movements: [paidIn(amount: 200000)],
        );
        await openGoal(tester);

        for (final label in ['Add money', 'Take out']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$label is truncated on $name',
          );
        }
      });
    }

    for (final (name, size) in [
      ('a phone', SavingsHarness.phone),
      ('a small phone', SavingsHarness.smallPhone),
    ]) {
      testWidgets('the add-money form fits $name', (tester) async {
        await SavingsHarness.pump(
          tester,
          size: size,
          goals: [goal(target: 500000, name: 'Deposit for a plot of land')],
          movements: [paidIn(amount: 200000)],
        );
        await openGoal(tester, 'Deposit for a plot of land');
        await tapText(tester, 'Add money');
        await SavingsHarness.dragTo(tester, find.text('Note'));

        expect(tester.takeException(), isNull);
      });

      testWidgets('the take-out form fits $name', (tester) async {
        await SavingsHarness.pump(
          tester,
          size: size,
          goals: [goal(target: 500000)],
          movements: [paidIn(amount: 200000)],
        );
        await openGoal(tester);
        await tapText(tester, 'Take out');
        await SavingsHarness.dragTo(
          tester,
          find.textContaining('lowers what this goal holds'),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
