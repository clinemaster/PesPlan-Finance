import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget_status.dart';
import 'package:lifepilot_finance/features/budgets/presentation/widgets/budget_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('the month', () {
    testWidgets('opens on this month, named and marked', (tester) async {
      await BudgetsHarness.pump(tester);

      // Twice: the app bar title and the bottom navigation label.
      expect(find.text('Budgets'), findsWidgets);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('this month'), findsOneWidget);
    });

    testWidgets('steps back a month', (tester) async {
      await BudgetsHarness.pump(tester);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('this month'), findsNothing);
    });

    testWidgets('steps back across the turn of the year', (tester) async {
      await BudgetsHarness.pump(tester);

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }

      expect(find.text('December 2025'), findsOneWidget);
    });

    testWidgets('will not step into a month that has not started', (
      tester,
    ) async {
      // Dimmed rather than hidden: a control that vanishes reads as a
      // bug, and walking forward into an empty 2027 looks broken too.
      await BudgetsHarness.pump(tester);

      final forward = tester.widget<AppIconButton>(
        find.ancestor(
          of: find.byTooltip('Next month'),
          matching: find.byType(AppIconButton),
        ),
      );
      expect(forward.onPressed, isNull);
    });

    testWidgets('offers forward again once standing in the past', (
      tester,
    ) async {
      await BudgetsHarness.pump(tester);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('a past month shows that month\'s plans, not this one\'s', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [
          plan(amount: 200000, id: 'nov', categoryLabel: 'Food'),
          plan(
            amount: 90000,
            id: 'oct',
            month: 10,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
        seed: const [],
      );

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsNothing);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
    });
  });

  group('the overall budget', () {
    testWidgets('leads with what is left to spend', (tester) async {
      // "How much is left" is the question someone standing in a shop is
      // actually asking, so it is the headline rather than spent.
      await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 1000000)],
        seed: [spent(amount: 400000)],
      );

      expect(find.text('Monthly budget'), findsOneWidget);
      expect(find.text('Left to spend'), findsOneWidget);
      expect(find.text('TSh 600,000'), findsOneWidget);
      expect(find.text('TSh 400,000 of TSh 1,000,000'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text(BudgetStatus.onTrack.label), findsOneWidget);
    });

    testWidgets('reports being over by how much, not a negative left', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 500000)],
        seed: [spent(amount: 650000)],
      );

      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('TSh 150,000'), findsOneWidget);
      expect(find.text('Left to spend'), findsNothing);
      expect(find.text(BudgetStatus.over.label), findsWidgets);
      expect(find.text('130%'), findsOneWidget);
    });

    testWidgets('invites one when the month has none', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 200000)],
        seed: const [],
      );

      expect(find.text('No overall budget'), findsOneWidget);
      expect(find.text('Set a monthly budget'), findsOneWidget);
      expect(find.text('Monthly budget'), findsNothing);
    });
  });

  group('the category list', () {
    testWidgets('shows each plan with its spend, share and what is left', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000, categoryLabel: 'Food')],
        seed: [spent(amount: 100000)],
      );

      expect(find.text('By category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('TSh 100,000 of TSh 250,000'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('TSh 150,000 left'), findsOneWidget);
    });

    testWidgets('says how far over, where it is over', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 100000, categoryLabel: 'Food')],
        seed: [spent(amount: 145000)],
      );

      expect(find.text('TSh 45,000 over'), findsOneWidget);
      expect(find.text('145%'), findsOneWidget);
    });

    testWidgets('orders them by pressure, worst first', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [
          plan(
            amount: 500000,
            id: 'housing',
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
          plan(amount: 100000, id: 'food'),
          plan(
            amount: 50000,
            id: 'transport',
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
        seed: [
          spent(
            id: 'a',
            amount: 100000,
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
          spent(id: 'b', amount: 130000),
          spent(
            id: 'c',
            amount: 40000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      final rows = tester
          .widgetList<CategoryBudgetRow>(find.byType(CategoryBudgetRow))
          .map((row) => row.progress.budget.categoryLabel)
          .toList();

      expect(rows, ['Food', 'Transport', 'Housing']);
    });

    testWidgets('badges only the rows worth acting on', (tester) async {
      // A chip on every row makes all of them wallpaper.
      await BudgetsHarness.pump(
        tester,
        plans: [
          plan(amount: 100000, id: 'food'),
          plan(
            amount: 100000,
            id: 'transport',
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
        seed: [
          spent(id: 'a', amount: 10000),
          spent(
            id: 'b',
            amount: 120000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      expect(find.text(BudgetStatus.over.label), findsOneWidget);
      expect(find.text(BudgetStatus.onTrack.label), findsNothing);
    });

    testWidgets('invites a first category budget when there are none', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 500000)],
        seed: const [],
      );

      expect(find.text('No category budgets yet'), findsOneWidget);
      expect(find.text('Add a category budget'), findsOneWidget);
    });

    testWidgets('reports spending nobody planned for', (tester) async {
      // Without it, a list adding up to less than the month's spending
      // looks like a bug — and unbudgeted spending is usually the part a
      // user did not realise was happening.
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 200000, id: 'food')],
        seed: [
          spent(id: 'a', amount: 50000),
          spent(
            id: 'b',
            amount: 70000,
            categoryId: 'bills',
            categoryLabel: 'Bills',
          ),
        ],
      );

      await BudgetsHarness.scrollTo(
        tester,
        find.textContaining('no budget set'),
      );

      expect(
        find.text('TSh 70,000 went on things with no budget set.'),
        findsOneWidget,
      );
    });
  });

  group('status levels', () {
    for (final (spending, level) in [
      (10000, BudgetStatus.onTrack),
      (80000, BudgetStatus.approaching),
      (95000, BudgetStatus.nearLimit),
      (130000, BudgetStatus.over),
    ]) {
      testWidgets("${level.name} is shown for $spending of 100,000", (
        tester,
      ) async {
        await BudgetsHarness.pump(
          tester,
          plans: [overallPlan(amount: 100000)],
          seed: [spent(amount: spending)],
        );

        expect(find.text(level.label), findsWidgets);
      });
    }
  });

  group('the bar and the label agree', () {
    // AppProgressBar turns amber at 80% by default, while this feature
    // calls 80% "Approaching limit" and paints its chip blue. Left to
    // the default, the overall card showed an amber bar under a blue
    // label — the exact inconsistency statusPaint exists to prevent.
    Future<Color> barColour(WidgetTester tester, int spending) async {
      await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 100000)],
        seed: [spent(amount: spending)],
      );

      final bar = tester.widget<AppProgressBar>(
        find.byType(AppProgressBar).first,
      );
      expect(bar.color, isNotNull, reason: 'the status must pick the colour');
      return bar.color!;
    }

    testWidgets('approaching is not painted as a warning', (tester) async {
      final colour = await barColour(tester, 82000);
      final context = tester.element(find.byType(OverallBudgetCard));

      expect(colour, context.colors.primary);
      expect(colour, isNot(context.finance.warning));
    });

    testWidgets('near limit is painted as a warning', (tester) async {
      final colour = await barColour(tester, 93000);
      final context = tester.element(find.byType(OverallBudgetCard));

      expect(colour, context.finance.warning);
    });

    testWidgets('over is painted as an expense', (tester) async {
      final colour = await barColour(tester, 130000);
      final context = tester.element(find.byType(OverallBudgetCard));

      expect(colour, context.finance.expense);
    });
  });

  group('the detail sheet', () {
    testWidgets('breaks one budget down', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [
          plan(amount: 250000, categoryLabel: 'Food', description: 'Groceries'),
        ],
        seed: [
          spent(id: 'a', amount: 60000),
          spent(id: 'b', amount: 40000),
        ],
      );

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Budgeted'), findsOneWidget);
      expect(find.text('TSh 250,000'), findsWidgets);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Used'), findsOneWidget);
      expect(find.text('40%'), findsWidgets);
      expect(find.text('November 2026'), findsWidgets);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text(BudgetStatus.onTrack.explanation), findsOneWidget);
    });

    testWidgets('counts the transactions behind the figure', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: [
          spent(id: 'a', amount: 60000),
          spent(id: 'b', amount: 40000),
        ],
      );

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('See the 2 transactions'), findsOneWidget);
    });

    testWidgets('says so when there is nothing to show yet', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: const [],
      );

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'No spending yet'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('opens the transactions behind it, filtered to the month', (
      tester,
    ) async {
      await BudgetsHarness.pump(
        tester,
        plans: [plan(amount: 250000)],
        seed: [spent(amount: 60000, description: 'Mlimani City')],
      );

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See the 1 transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsWidgets);
      expect(find.text('Mlimani City'), findsWidgets);
    });

    testWidgets('leads with how much is left, and the status', (tester) async {
      await BudgetsHarness.pump(
        tester,
        plans: [overallPlan(amount: 200000)],
        seed: [spent(amount: 190000)],
      );

      await tester.tap(find.text('Monthly budget'));
      await tester.pumpAndSettle();

      expect(find.text('Left to spend'), findsWidgets);
      expect(find.text('TSh 10,000'), findsWidgets);
      expect(find.text(BudgetStatus.nearLimit.explanation), findsOneWidget);
      expect(find.text('Overall'), findsOneWidget);
    });
  });

  group('the empty month', () {
    testWidgets('invites a first budget rather than showing zeroes', (
      tester,
    ) async {
      await BudgetsHarness.pump(tester, plans: const []);

      expect(find.text('Start planning your spending.'), findsOneWidget);
      expect(
        find.text('Create a budget to see how your money is being used.'),
        findsOneWidget,
      );
      expect(find.text('Create budget'), findsWidgets);
      expect(find.byType(CategoryBudgetRow), findsNothing);
    });

    testWidgets('a past month is not an invitation to plan backwards', (
      tester,
    ) async {
      await BudgetsHarness.pump(tester, plans: const []);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No budgets were set'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create budget'), findsNothing);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', BudgetsHarness.phone),
      ('a small phone', BudgetsHarness.smallPhone),
    ]) {
      testWidgets('renders on $name without overflowing', (tester) async {
        await BudgetsHarness.pump(tester, size: size);
        await BudgetsHarness.scrollTo(tester, find.text('Create budget'));

        expect(tester.takeException(), isNull);
      });

      testWidgets('the detail sheet fits $name', (tester) async {
        await BudgetsHarness.pump(
          tester,
          size: size,
          plans: [
            plan(
              amount: 250000,
              description: 'A note long enough to wrap onto a second line',
            ),
          ],
          seed: [spent(amount: 300000)],
        );

        await tester.tap(find.text('Food'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('the empty month fits $name', (tester) async {
        await BudgetsHarness.pump(tester, size: size, plans: const []);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
