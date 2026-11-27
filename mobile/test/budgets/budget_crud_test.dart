import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// The amount is the first TextField on the form and the note is the
/// last. The type is two buttons and the category is a row of chips, so
/// neither is a TextField — which is what keeps these stable.
Finder get amountField => find.byType(TextField).first;
Finder get noteField => find.byType(TextField).last;

Future<void> openNewBudget(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Create budget'));
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
    testWidgets('a category budget appears in the list immediately', (
      tester,
    ) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: const [],
        seed: [spent(amount: 90000)],
      );
      await openNewBudget(tester);

      expect(find.text('New budget'), findsOneWidget);

      await enter(tester, amountField, '250000');
      await tapText(tester, 'Food');
      await enter(tester, noteField, 'Groceries and lunches');
      await tapText(tester, 'Create budget');

      expect(harness.budgets.all, hasLength(1));
      final saved = harness.budgets.all.single;
      expect(saved.kind, BudgetKind.category);
      expect(saved.amount.minorUnits, 250000);
      expect(saved.categoryId, 'food');
      expect(saved.description, 'Groceries and lunches');

      // And it is measured against what was already spent, not from zero.
      expect(find.text('TSh 90,000 of TSh 250,000'), findsOneWidget);
      expect(find.text('36%'), findsOneWidget);
    });

    testWidgets('an overall budget asks for no category', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: const [],
        seed: const [],
      );
      await openNewBudget(tester);

      await tapText(tester, 'Whole month');
      expect(find.text('Category'), findsNothing);
      expect(find.text('Food'), findsNothing);

      await enter(tester, amountField, '1200000');
      await tapText(tester, 'Create budget');

      expect(harness.budgets.all.single.kind, BudgetKind.overall);
      expect(harness.budgets.all.single.categoryId, isNull);
      expect(find.text('Monthly budget'), findsOneWidget);
    });

    testWidgets('switching to the whole month drops a chosen category', (
      tester,
    ) async {
      // Saving a category alongside an overall budget would confuse every
      // later read of it.
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await tapText(tester, 'Food');
      await tapText(tester, 'Whole month');
      await enter(tester, amountField, '500000');
      await tapText(tester, 'Create budget');

      expect(harness.budgets.all.single.categoryId, isNull);
      expect(harness.budgets.all.single.categoryLabel, isNull);
    });

    testWidgets('the invitation to set a monthly budget preselects it', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 200000)],
        seed: const [],
      );

      await tapText(tester, 'Set a monthly budget');

      // Landing on a form that still says "One category" would ignore
      // what the user just pressed.
      expect(find.text('Category'), findsNothing);
      expect(find.text('The most you plan to spend all month'), findsOneWidget);
    });

    testWidgets('confirms the save and returns to the list', (tester) async {
      await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await enter(tester, amountField, '60000');
      await tapText(tester, 'Bills');
      await tapText(tester, 'Create budget');

      expect(find.text('Budget created'), findsOneWidget);
      expect(find.text('New budget'), findsNothing);
    });

    testWidgets('files the budget in the month on screen', (tester) async {
      // The month is shown, not chosen: the user came from a screen
      // already showing one, and asking them to pick it again invites
      // picking the wrong one.
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      await openNewBudget(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      await enter(tester, amountField, '40000');
      await tapText(tester, 'Transport');
      await tapText(tester, 'Create budget');

      expect(harness.budgets.all.single.month, 10);
      expect(harness.budgets.all.single.year, 2026);
    });
  });

  group('validation', () {
    testWidgets('an empty amount is refused, and nothing is saved', (
      tester,
    ) async {
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await tapText(tester, 'Food');
      await tapText(tester, 'Create budget');

      expect(find.text('Enter an amount'), findsOneWidget);
      expect(harness.budgets.all, isEmpty);
    });

    testWidgets('zero is refused', (tester) async {
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await enter(tester, amountField, '0');
      await tapText(tester, 'Food');
      await tapText(tester, 'Create budget');

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(harness.budgets.all, isEmpty);
    });

    testWidgets('a missing category is refused', (tester) async {
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await enter(tester, amountField, '100000');
      await tapText(tester, 'Create budget');

      expect(find.text('Choose a category'), findsOneWidget);
      expect(harness.budgets.all, isEmpty);
    });

    testWidgets('a note past the cap is refused', (tester) async {
      final harness = await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await enter(tester, amountField, '100000');
      await tapText(tester, 'Food');
      await enter(tester, noteField, 'x' * 120);
      await tapText(tester, 'Create budget');

      expect(find.textContaining('Keep it under'), findsOneWidget);
      expect(harness.budgets.all, isEmpty);
    });

    testWidgets('a second budget for the same category is refused by name', (
      tester,
    ) async {
      // Two bars for Food cannot both be the plan, and the arithmetic
      // under them would double-count the month.
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000, id: 'food')],
        seed: const [],
      );
      await openNewBudget(tester);

      await enter(tester, amountField, '300000');
      await tapText(tester, 'Food');
      await tapText(tester, 'Create budget');

      expect(
        find.textContaining('Food already has a budget this month'),
        findsOneWidget,
      );
      expect(harness.budgets.all, hasLength(1));
    });

    testWidgets('a second overall budget is refused', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 900000)],
        seed: const [],
      );
      await openNewBudget(tester);

      await tapText(tester, 'Whole month');
      await enter(tester, amountField, '300000');
      await tapText(tester, 'Create budget');

      expect(
        find.textContaining('already has an overall budget'),
        findsOneWidget,
      );
      expect(harness.budgets.all, hasLength(1));
    });

    testWidgets('fixing the amount clears the message', (tester) async {
      await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      await tapText(tester, 'Food');
      await tapText(tester, 'Create budget');
      expect(find.text('Enter an amount'), findsOneWidget);

      await enter(tester, amountField, '150000');
      expect(find.text('Enter an amount'), findsNothing);
    });

    testWidgets('errors appear only once the user has tried to save', (
      tester,
    ) async {
      // A form that is red before it has been touched reads as broken.
      await BudgetsHarness.pump(tester, plans: const []);
      await openNewBudget(tester);

      expect(find.text('Enter an amount'), findsNothing);
      expect(find.text('Choose a category'), findsNothing);
    });
  });

  group('editing', () {
    Future<void> openEditor(WidgetTester tester, String label) async {
      await tapText(tester, label);
      await tapText(tester, 'Edit');
    }

    testWidgets('the form opens pre-filled', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000, description: 'Groceries')],
        seed: const [],
      );
      await openEditor(tester, 'Food');

      expect(find.text('Edit budget'), findsOneWidget);
      expect(find.text('250000'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('a new limit is stored and the bars move', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 100000)],
        seed: [spent(amount: 80000)],
      );
      expect(find.text('80%'), findsOneWidget);

      await openEditor(tester, 'Food');
      await enter(tester, amountField, '400000');
      await tapText(tester, 'Save changes');

      expect(harness.budgets.all.single.amount.minorUnits, 400000);
      expect(find.text('Budget updated'), findsOneWidget);
      expect(find.text('TSh 80,000 of TSh 400,000'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('the same budget is not reported as its own duplicate', (
      tester,
    ) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 100000)],
        seed: const [],
      );

      await openEditor(tester, 'Food');
      await enter(tester, amountField, '120000');
      await tapText(tester, 'Save changes');

      expect(find.textContaining('already has a budget'), findsNothing);
      expect(harness.budgets.all.single.amount.minorUnits, 120000);
    });

    testWidgets('editing keeps the month it was filed under', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 100000, month: 10)],
        seed: const [],
      );
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      await openEditor(tester, 'Food');
      expect(find.text('October 2026'), findsOneWidget);

      await enter(tester, amountField, '150000');
      await tapText(tester, 'Save changes');

      expect(harness.budgets.all.single.month, 10);
    });

    testWidgets('a budget that is gone says so instead of failing', (
      tester,
    ) async {
      // Delete sits beside Edit in the detail sheet, so this is a real
      // case rather than a defensive branch.
      await BudgetsHarness.pump(
        tester,
        route: Routes.budgetEdit('no-such-budget'),
        plans: const [],
      );

      expect(find.text('That budget is gone'), findsOneWidget);
      expect(find.text('Back to budgets'), findsOneWidget);
    });
  });

  group('deleting', () {
    Future<void> openDetail(WidgetTester tester, String label) =>
        tapText(tester, label);

    testWidgets('asks first, naming the budget and the amount', (tester) async {
      // A confirmation that only says "this budget" is one people agree
      // to without reading.
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: const [],
      );

      await openDetail(tester, 'Food');
      await tapText(tester, 'Delete');

      expect(find.text('Delete this budget?'), findsOneWidget);
      expect(
        find.textContaining('TSh 250,000 budget for Food in November'),
        findsOneWidget,
      );
      expect(
        find.textContaining('transactions are not affected'),
        findsOneWidget,
      );
      expect(harness.budgets.all, hasLength(1));
    });

    testWidgets('cancelling keeps it', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: const [],
      );

      await openDetail(tester, 'Food');
      await tapText(tester, 'Delete');
      await tapText(tester, 'Cancel');

      expect(harness.budgets.all, hasLength(1));
    });

    testWidgets('confirming removes it from the list', (tester) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [
          plan(amount: 250000, id: 'food'),
          plan(
            amount: 40000,
            id: 'transport',
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
        seed: const [],
      );

      await openDetail(tester, 'Food');
      await tapText(tester, 'Delete');
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(harness.budgets.all.map((b) => b.id), ['transport']);
      expect(find.text('Budget deleted'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      expect(find.text('Transport'), findsOneWidget);
    });

    testWidgets('deleting the last one leaves the empty state, not zeroes', (
      tester,
    ) async {
      final harness = await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: const [],
      );

      await openDetail(tester, 'Food');
      await tapText(tester, 'Delete');
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(harness.budgets.all, isEmpty);
      expect(find.text('Start planning your spending.'), findsOneWidget);
    });
  });

  group('the dashboard card', () {
    testWidgets('quotes the limit the user set', (tester) async {
      // The card, the Money out figure above it and the Budgets screen
      // read the same plan, so they cannot disagree.
      await BudgetsHarness.pump(
        tester,
        route: Routes.home,
        plans: [overallPlan(amount: 1000000)],
        seed: [spent(amount: 400000)],
      );

      await tester.scrollUntilVisible(
        find.text('Monthly budget'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Stacked rather than side by side: two seven-digit amounts on one
      // line overflow a phone.
      expect(find.text('TSh 400,000'), findsWidgets);
      expect(find.text('of TSh 1,000,000'), findsOneWidget);
      expect(find.text('TSh 600,000 left'), findsOneWidget);
    });

    testWidgets('invites one when the month has no overall budget', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        route: Routes.home,
        plans: [plan(amount: 200000)],
        seed: [spent(amount: 40000)],
      );

      await tester.scrollUntilVisible(
        find.text('No budget set'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('No budget set'), findsOneWidget);
    });

    testWidgets('opens the Budgets tab', (tester) async {
      await BudgetsHarness.pump(
        tester,
        route: Routes.home,
        plans: [overallPlan(amount: 1000000)],
        seed: [spent(amount: 400000)],
      );

      await tester.scrollUntilVisible(
        find.text('Budget'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // "View all" appears over three sections, so this takes the one
      // inside the Budget header rather than whichever came first.
      final header = find.ancestor(
        of: find.text('Budget'),
        matching: find.byType(SectionHeader),
      );
      await tester.tap(
        find.descendant(of: header, matching: find.text('View all')),
      );
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
    });
  });
}
