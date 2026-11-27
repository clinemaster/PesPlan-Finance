import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/savings/presentation/widgets/savings_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('the overview', () {
    testWidgets('leads with everything set aside', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 2000000)],
        movements: [paidIn(amount: 850000)],
      );

      // Twice: the app bar title and the bottom navigation label.
      expect(find.text('Goals'), findsWidgets);
      expect(find.text('Set aside'), findsOneWidget);
      expect(find.text('TSh 850,000'), findsWidgets);
      expect(find.text('of TSh 2,000,000 across active goals'), findsOneWidget);
      expect(find.text('1 goal'), findsOneWidget);
    });

    testWidgets('counts only the goals still being saved toward', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(target: 500000, id: 'open', name: 'Open'),
          goal(target: 300000, id: 'done', name: 'Done'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'open', amount: 200000),
          paidIn(id: 'm2', goalId: 'done', amount: 300000),
        ],
      );

      expect(find.text('1 goal'), findsOneWidget);
      expect(find.text('TSh 200,000'), findsWidgets);
      expect(find.text('40% of what you are saving toward'), findsOneWidget);
    });
  });

  group('a goal card', () {
    testWidgets('shows the name, the figures, the share and what is left', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 2000000, name: 'Emergency fund')],
        movements: [paidIn(amount: 850000)],
      );

      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('TSh 850,000 of TSh 2,000,000'), findsOneWidget);
      expect(find.text('43%'), findsOneWidget);
      expect(find.text('TSh 1,150,000 to go'), findsOneWidget);
    });

    testWidgets('shows how long is left when a date is set', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(
            target: 1500000,
            name: 'New laptop',
            targetDate: DateTime(2027, 3, 31),
          ),
        ],
        movements: [paidIn(amount: 300000)],
      );

      expect(find.text('4 months to go'), findsOneWidget);
    });

    testWidgets('says nothing about timing when there is no date', (
      tester,
    ) async {
      // A goal with no date is a goal all the same — "when I can" is how
      // most emergency funds are actually saved.
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );

      expect(find.textContaining('to go,'), findsNothing);
      expect(find.textContaining('months'), findsNothing);
    });

    testWidgets('orders them closest to done first', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(target: 1000000, id: 'early', name: 'Early'),
          goal(target: 200000, id: 'close', name: 'Close'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'early', amount: 100000),
          paidIn(id: 'm2', goalId: 'close', amount: 180000),
        ],
      );

      final names = tester
          .widgetList<GoalCard>(find.byType(GoalCard))
          .map((card) => card.progress.goal.name)
          .toList();

      expect(names, ['Close', 'Early']);
    });
  });

  group('completed goals', () {
    testWidgets('sit in their own section, marked complete', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [
          goal(target: 500000, id: 'open', name: 'Still going'),
          goal(target: 300000, id: 'done', name: 'School fees'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'open', amount: 100000),
          paidIn(id: 'm2', goalId: 'done', amount: 300000),
        ],
      );

      await SavingsHarness.scrollTo(tester, find.text('Reached'));

      expect(find.text('Reached'), findsOneWidget);
      expect(find.text('One goal you finished'), findsOneWidget);
      expect(find.text('School fees'), findsOneWidget);
      expect(find.text('Target reached'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('are not shown when nothing is finished', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 100000)],
      );

      expect(find.text('Reached'), findsNothing);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('a goal is never rounded into completion', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Nearly there')],
        movements: [paidIn(amount: 499999)],
      );

      expect(find.text('Reached'), findsNothing);
      expect(find.text('TSh 1 to go'), findsOneWidget);
    });

    testWidgets('everything finished still invites the next one', (
      tester,
    ) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 300000, name: 'School fees')],
        movements: [paidIn(amount: 300000)],
      );

      expect(find.text('Nothing in progress'), findsOneWidget);
      expect(
        find.textContaining('Every goal you set has been reached'),
        findsOneWidget,
      );
      expect(find.text('School fees'), findsOneWidget);
    });
  });

  group('the empty state', () {
    testWidgets('invites a first goal rather than showing zeroes', (
      tester,
    ) async {
      // No goals is not zero goals worth of progress: a headline of
      // TSh 0 states a financial fact the app has no basis for.
      await SavingsHarness.pump(tester, goals: const []);

      expect(find.text('No savings goals yet.'), findsOneWidget);
      expect(
        find.textContaining('Start saving toward something that matters'),
        findsOneWidget,
      );
      expect(find.text('Create goal'), findsWidgets);
      expect(find.text('Set aside'), findsNothing);
      expect(find.text('TSh 0'), findsNothing);
      expect(find.byType(GoalCard), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('a card opens its goal', (tester) async {
      await SavingsHarness.pump(
        tester,
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000, description: 'First month')],
      );

      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();

      expect(find.text('Saved so far'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('First month'), findsOneWidget);
    });

    testWidgets('the dashboard preview opens Goals', (tester) async {
      await SavingsHarness.pump(
        tester,
        route: '/home',
        goals: [goal(target: 500000, name: 'Emergency fund')],
        movements: [paidIn(amount: 100000)],
      );

      await tester.scrollUntilVisible(
        find.text('Savings goals'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final header = find.ancestor(
        of: find.text('Savings goals'),
        matching: find.byType(SectionHeader),
      );
      await tester.tap(
        find.descendant(of: header, matching: find.text('View all')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set aside'), findsWidgets);
      expect(find.text('Saving toward'), findsOneWidget);
    });

    testWidgets('the dashboard quotes the same figures as Goals', (
      tester,
    ) async {
      // The card and the screen one tap away read the same repository,
      // so they cannot disagree about what has been put aside.
      await SavingsHarness.pump(
        tester,
        route: '/home',
        goals: [goal(target: 2000000, name: 'Emergency fund')],
        movements: [paidIn(amount: 850000)],
      );

      await tester.scrollUntilVisible(
        find.text('Savings goals'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('TSh 850,000'), findsWidgets);
      expect(find.text('of TSh 2,000,000 target'), findsOneWidget);
      expect(find.text('1 goal'), findsOneWidget);
    });

    testWidgets('the dashboard invites a first goal when there are none', (
      tester,
    ) async {
      await SavingsHarness.pump(tester, route: '/home', goals: const []);

      await tester.scrollUntilVisible(
        find.text('Savings goals'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('No goals yet'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', SavingsHarness.phone),
      ('a small phone', SavingsHarness.smallPhone),
    ]) {
      testWidgets('the list renders on $name without overflowing', (
        tester,
      ) async {
        await SavingsHarness.pump(tester, size: size);
        await SavingsHarness.scrollTo(tester, find.text('Reached'));

        expect(tester.takeException(), isNull);
      });

      testWidgets('the empty state fits $name', (tester) async {
        await SavingsHarness.pump(tester, size: size, goals: const []);

        expect(tester.takeException(), isNull);
      });

      testWidgets('a goal with a long name fits $name', (tester) async {
        await SavingsHarness.pump(
          tester,
          size: size,
          goals: [
            goal(
              target: 12000000,
              name: 'Deposit for a plot of land in Dodoma',
              targetDate: DateTime(2029, 12, 31),
            ),
          ],
          movements: [paidIn(amount: 3450000)],
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
