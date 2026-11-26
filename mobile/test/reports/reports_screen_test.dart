import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/reports/presentation/providers/report_providers.dart';
import 'package:lifepilot_finance/features/shell/presentation/main_shell.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('the overview', () {
    testWidgets('opens on this month', (tester) async {
      final harness = await ReportsHarness.pump(tester);

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(
        harness.container.read(reportPeriodProvider).kind,
        ReportPeriodKind.month,
      );
    });

    testWidgets('shows in, out and net', (tester) async {
      await ReportsHarness.pump(tester);

      expect(find.text('Net movement'), findsOneWidget);
      expect(find.text('Money in'), findsOneWidget);
      expect(find.text('Money out'), findsOneWidget);
    });

    testWidgets('never presents the net as a balance', (tester) async {
      await ReportsHarness.pump(tester);

      expect(
        find.text('Income minus expenses · not an account balance'),
        findsOneWidget,
      );
      expect(find.textContaining('Available balance'), findsNothing);
    });

    testWidgets('warns that an unfinished period is partial', (tester) async {
      // Without it a part-month sits beside a full one and reads as a
      // collapse in spending.
      await ReportsHarness.pump(tester);

      expect(find.textContaining('still running'), findsWidgets);
    });

    testWidgets('shows metrics and a category breakdown', (tester) async {
      await ReportsHarness.pump(tester);

      expect(find.text('Transactions'), findsWidgets);

      await ReportsHarness.scrollTo(tester, find.text('Where it went'));
      expect(find.text('Where it went'), findsOneWidget);
    });
  });

  group('period selection', () {
    for (final (label, kind) in [
      ('Day', ReportPeriodKind.today),
      ('Week', ReportPeriodKind.week),
      ('Year', ReportPeriodKind.year),
    ]) {
      testWidgets('$label switches the window', (tester) async {
        final harness = await ReportsHarness.pump(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(harness.container.read(reportPeriodProvider).kind, kind);
      });
    }

    testWidgets('a year shows its own title and figures', (tester) async {
      await ReportsHarness.pump(tester);

      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('a single day says it has no trend rather than drawing one', (
      tester,
    ) async {
      await ReportsHarness.pump(tester);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no trend to show'), findsOneWidget);
    });
  });

  group('stepping through periods', () {
    testWidgets('back moves to the previous month', (tester) async {
      await ReportsHarness.pump(tester);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('forward is disabled at the present edge', (tester) async {
      // A control that vanishes reads as a bug; a dimmed one says there
      // is nothing that way.
      final harness = await ReportsHarness.pump(tester);

      expect(harness.container.read(reportPeriodProvider).canGoNext(
        ReportsHarness.now,
      ), isFalse);

      await tester.tap(find.byTooltip('Next period'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('forward works once there is somewhere to go', (tester) async {
      await ReportsHarness.pump(tester);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Next period'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('stepping back crosses a year boundary', (tester) async {
      final harness = await ReportsHarness.pump(tester);
      final controller = harness.container.read(
        reportPeriodProvider.notifier,
      );

      controller.select(ReportPeriod.monthOf(2026, 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();

      expect(find.text('December 2025'), findsOneWidget);
    });
  });

  group('empty and sparse data', () {
    testWidgets('a period with no records says so without claiming the '
        'account is empty', (tester) async {
      final harness = await ReportsHarness.pump(tester);

      harness.container
          .read(reportPeriodProvider.notifier)
          .select(ReportPeriod.monthOf(2019, 5));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing in May 2019'), findsOneWidget);
      expect(find.textContaining('Step back to an earlier one'), findsOneWidget);
    });

    testWidgets('an account with nothing at all still renders', (
      tester,
    ) async {
      await ReportsHarness.pump(tester, seed: const []);

      expect(find.textContaining('Nothing in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('drill-down', () {
    testWidgets('tapping a category opens those transactions', (tester) async {
      // Reuses the transactions screen rather than growing a second list
      // inside reports.
      final harness = await ReportsHarness.pump(tester);
      await ReportsHarness.scrollTo(tester, find.text('Where it went'));

      await tester.tap(find.text('Housing').first);
      await tester.pumpAndSettle();

      final filter = harness.container.read(transactionFilterProvider);
      expect(filter.categoryIds, {'housing'});
      expect(filter.from, DateTime(2026, 11));
      expect(filter.to, DateTime(2026, 11, 30));
      expect(find.text('Transactions'), findsWidgets);
    });
  });

  group('navigation in', () {
    testWidgets('the dashboard offers a reports action', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.home);

      await tester.tap(find.byTooltip('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsWidgets);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('so does the transactions screen', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.transactions);

      await tester.tap(find.byTooltip('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('and reports goes back where it came from', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.home);

      await tester.tap(find.byTooltip('Reports'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.textContaining('Amina'), findsWidgets);
    });

    testWidgets('reports is not a sixth bottom tab', (tester) async {
      // Five is the bar's limit; a sixth would narrow every target.
      await ReportsHarness.pump(tester, route: Routes.home);

      expect(MainShell.destinations, hasLength(5));
      expect(
        MainShell.destinations.map((d) => d.label),
        isNot(contains('Reports')),
      );
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', ReportsHarness.phone),
      ('a small phone', ReportsHarness.smallPhone),
    ]) {
      testWidgets('renders on $name without overflowing', (tester) async {
        await ReportsHarness.pump(tester, size: size);
        await ReportsHarness.scrollTo(tester, find.text('Where it went'));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a year view also fits a small phone', (tester) async {
      await ReportsHarness.pump(tester, size: ReportsHarness.smallPhone);

      // Five chips do not fit 320px, so the selector scrolls — which is
      // the intended behaviour, and what this has to do to reach Year.
      await tester.scrollUntilVisible(
        find.text('Year'),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
