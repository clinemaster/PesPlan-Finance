import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/domain/dashboard_period.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/widgets/quick_actions.dart';

import 'harness.dart';

void main() {
  group('header', () {
    testWidgets('greets by first name, with the time of day', (tester) async {
      await DashboardHarness.pump(tester, now: DateTime(2026, 11, 26, 9));

      expect(find.textContaining('Good morning, Amina'), findsOneWidget);
      expect(find.text("Here's your financial overview."), findsOneWidget);
    });

    testWidgets('the greeting follows the clock', (tester) async {
      await DashboardHarness.pump(tester, now: DateTime(2026, 11, 26, 19));

      expect(find.textContaining('Good evening, Amina'), findsOneWidget);
    });

    testWidgets('offers settings and notifications', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.bySemanticsLabel('Profile and settings'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    testWidgets('notifications says plainly that it does nothing yet', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.textContaining('later phase'), findsOneWidget);
    });
  });

  group('summary', () {
    testWidgets('shows money in, money out and the net', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.text('Money in'), findsOneWidget);
      expect(find.text('Money out'), findsOneWidget);
      expect(find.text('Net this month'), findsOneWidget);

      expect(find.text('TSh 3,200,000'), findsWidgets);
      expect(find.text('TSh 1,875,500'), findsWidgets);
      expect(find.text('TSh 1,324,500'), findsWidgets);
    });

    testWidgets('never calls the net a balance', (tester) async {
      // The product cannot see anyone's bank account. A hero figure
      // labelled "balance" would be a claim it has no basis for, and the
      // user would find the gap the first time they checked their bank.
      await DashboardHarness.pump(tester);

      expect(find.textContaining('Available balance'), findsNothing);
      expect(find.textContaining('Your balance'), findsNothing);
      expect(
        find.text('Income minus expenses · not an account balance'),
        findsOneWidget,
      );
    });
  });

  group('period selector', () {
    testWidgets('opens on this month', (tester) async {
      final harness = await DashboardHarness.pump(tester);

      expect(
        harness.container.read(selectedPeriodProvider).kind,
        PeriodKind.thisMonth,
      );
      expect(find.text('This month'), findsWidgets);
    });

    testWidgets('choosing the year changes the figures', (tester) async {
      final harness = await DashboardHarness.pump(tester);

      await tester.tap(find.text('This year'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(selectedPeriodProvider).kind,
        PeriodKind.thisYear,
      );
      expect(find.text('Net this year'), findsOneWidget);
      expect(find.text('TSh 31,950,000'), findsWidgets);
    });

    testWidgets('the chart switches form with the period', (tester) async {
      // Bars for four weeks, a line for twelve months: twenty-four bars on
      // a phone is present but not readable.
      await DashboardHarness.pump(tester);
      expect(find.byType(AppBarChart), findsOneWidget);
      expect(find.byType(AppLineChart), findsNothing);

      await tester.tap(find.text('This year'));
      await tester.pumpAndSettle();

      expect(find.byType(AppLineChart), findsOneWidget);
      expect(find.byType(AppBarChart), findsNothing);
    });
  });

  group('chart', () {
    testWidgets('renders with both series labelled', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.text('Income and spending'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Spending'), findsOneWidget);
    });

    testWidgets('the figures are reachable as a table', (tester) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 4'), findsOneWidget);
    });
  });

  group('budget', () {
    testWidgets('summarises spend against the limit', (tester) async {
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Monthly budget'));

      expect(find.text('Monthly budget'), findsOneWidget);
      expect(find.text('of TSh 2,200,000'), findsOneWidget);
      expect(find.text('TSh 324,500 left'), findsOneWidget);
      expect(find.text('Close to limit'), findsOneWidget);
    });

    testWidgets('links to the budgets tab', (tester) async {
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Budget'));

      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('View all'), findsWidgets);
    });
  });

  group('savings', () {
    testWidgets('shows the total, the count and two goals', (tester) async {
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Savings goals'));

      expect(find.text('Set aside'), findsOneWidget);
      expect(find.text('3 goals'), findsOneWidget);
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('New laptop'), findsOneWidget);
    });
  });

  group('recent activity', () {
    testWidgets('lists five transactions with their categories', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Recent activity'));

      expect(find.byType(TransactionTile), findsNWidgets(5));
      expect(find.text('Shoprite Mlimani City'), findsOneWidget);
      expect(find.text('Salary — November'), findsOneWidget);
    });

    testWidgets('a long description truncates rather than overflows', (
      tester,
    ) async {
      await DashboardHarness.pump(tester, size: DashboardHarness.smallPhone);
      await DashboardHarness.scrollTo(tester, find.text('Recent activity'));

      expect(tester.takeException(), isNull);
    });
  });

  group('quick actions', () {
    testWidgets('offers all three, high on the screen', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.byType(QuickActions), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('Add income'), findsOneWidget);
      expect(find.text('By voice'), findsOneWidget);
    });

    for (final (label, destination) in [
      ('Add expense', 'New transaction'),
      ('Add income', 'New transaction'),
      ('By voice', 'Record by voice'),
    ]) {
      testWidgets('$label opens its screen and comes back', (tester) async {
        await DashboardHarness.pump(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(destination), findsWidgets);

        // Pushed over the shell, so it dismisses back to the dashboard.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.textContaining('Good morning, Amina'), findsOneWidget);
      });
    }

    testWidgets('each action opens the form on the right side of the ledger', (
      tester,
    ) async {
      // The quick action is the whole point: pressing "Add income" and
      // landing on an expense form would make the shortcut worse than the
      // long way round. The helper under the amount is the visible proof.
      await DashboardHarness.pump(tester);

      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();
      expect(find.text('How much came in'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('How much went out'), findsOneWidget);
    });

    testWidgets('the voice action still promises nothing is saved', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.text('By voice'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No microphone is used'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('welcomes instead of showing zeroes', (tester) async {
      await DashboardHarness.pump(tester, data: MockDataMode.empty);

      expect(find.text('Your money journey starts here.'), findsOneWidget);
      expect(
        find.textContaining('Record your first income or expense'),
        findsOneWidget,
      );
    });

    testWidgets('shows no fabricated totals', (tester) async {
      // The whole point: an empty account must not have a budget bar at 0%
      // or a net of TSh 0, both of which state something untrue.
      await DashboardHarness.pump(tester, data: MockDataMode.empty);

      expect(find.text('Money in'), findsNothing);
      expect(find.text('Net this month'), findsNothing);
      expect(find.text('Monthly budget'), findsNothing);
      expect(find.byType(TransactionTile), findsNothing);
      expect(find.textContaining('TSh'), findsNothing);
    });

    testWidgets('still greets the user and offers a way in', (tester) async {
      await DashboardHarness.pump(tester, data: MockDataMode.empty);

      expect(find.textContaining('Good morning, Amina'), findsOneWidget);
      expect(find.text('Add your first expense'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a normal phone', DashboardHarness.phone),
      ('a small phone', DashboardHarness.smallPhone),
    ]) {
      testWidgets('renders on $name without overflowing', (tester) async {
        await DashboardHarness.pump(tester, size: size);

        // Scroll the whole page; an overflow anywhere raises here.
        await DashboardHarness.scrollTo(tester, find.text('Recent activity'));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the year view also fits a small phone', (tester) async {
      await DashboardHarness.pump(tester, size: DashboardHarness.smallPhone);

      await tester.tap(find.text('This year'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
