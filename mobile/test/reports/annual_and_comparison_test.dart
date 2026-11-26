import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/reports/presentation/providers/report_providers.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';

import 'harness.dart';

Transaction make({
  required String id,
  required TransactionType type,
  required int magnitude,
  required DateTime date,
  String categoryId = 'food',
  String categoryLabel = 'Food',
}) => Transaction.create(
  id: id,
  type: type,
  magnitudeMinorUnits: magnitude,
  categoryId: categoryId,
  categoryLabel: categoryLabel,
  date: date,
  createdAt: date,
);

void main() {
  group('the annual report', () {
    testWidgets('opens on the current year', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);

      expect(find.text('Annual report'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('says the current year is still running', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);

      expect(find.textContaining('still running'), findsWidgets);
      expect(
        find.textContaining('over the months so far, not twelve'),
        findsOneWidget,
      );
    });

    testWidgets('steps back a year, and forward again', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);

      await tester.tap(find.byTooltip('Next period'));
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('cannot step into a future year', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);

      await tester.tap(find.byTooltip('Next period'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2027'), findsNothing);
    });

    testWidgets('shows monthly averages and the biggest month', (
      tester,
    ) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();

      expect(find.text('Average month'), findsNWidgets(2));
      expect(find.text('Biggest month'), findsOneWidget);
    });

    testWidgets('charts the year month by month', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsAnnual);
      await ReportsHarness.scrollTo(tester, find.text('Month by month'));

      expect(find.text('Month by month'), findsOneWidget);
      expect(find.byType(AppLineChart), findsOneWidget);
    });

    testWidgets('a year with no records says so', (tester) async {
      await ReportsHarness.pump(
        tester,
        route: Routes.reportsAnnual,
        seed: const [],
      );

      expect(find.textContaining('Nothing recorded in 2026'), findsOneWidget);
    });
  });

  group('month drill-down', () {
    testWidgets('a month in the table opens its own report', (tester) async {
      final harness = await ReportsHarness.pump(
        tester,
        route: Routes.reportsAnnual,
      );

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      await ReportsHarness.scrollTo(tester, find.text('Month by month'));

      // The figures live behind the chart's table toggle, which is also
      // where the drill-down rows are — a table row is reachable by a
      // screen reader where a painted bar is not.
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(reportPeriodProvider),
        ReportPeriod.monthOf(2025, 3),
      );
      expect(find.text('March 2025'), findsOneWidget);
    });
  });

  group('year comparison', () {
    testWidgets('defaults to the two most recent years', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsCompare);

      expect(find.text('Compare years'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Net movement'), findsOneWidget);
    });

    testWidgets('warns when one year is incomplete', (tester) async {
      // 2026 has not ended, so comparing it with 2025 measures unequal
      // stretches of time.
      await ReportsHarness.pump(tester, route: Routes.reportsCompare);

      expect(
        find.textContaining('compare unequal stretches of time'),
        findsOneWidget,
      );
    });

    testWidgets('two finished years carry no warning', (tester) async {
      final harness = await ReportsHarness.pump(
        tester,
        route: Routes.reportsCompare,
      );

      harness.container
          .read(comparisonYearsProvider.notifier)
          .select(const ComparisonYears(2024, 2025));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('compare unequal stretches of time'),
        findsNothing,
      );
    });

    testWidgets('picking the same year twice asks for two', (tester) async {
      final harness = await ReportsHarness.pump(
        tester,
        route: Routes.reportsCompare,
      );

      harness.container
          .read(comparisonYearsProvider.notifier)
          .select(const ComparisonYears(2025, 2025));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Pick two different years'),
        findsOneWidget,
      );
    });

    testWidgets('compares by category too', (tester) async {
      await ReportsHarness.pump(tester, route: Routes.reportsCompare);
      await ReportsHarness.scrollTo(tester, find.text('By category'));

      expect(find.text('By category'), findsOneWidget);
      expect(find.text('Housing'), findsWidgets);
    });

    testWidgets('an account with one year of records cannot compare', (
      tester,
    ) async {
      await ReportsHarness.pump(
        tester,
        route: Routes.reportsCompare,
        seed: [
          make(
            id: 'a',
            type: TransactionType.expense,
            magnitude: 1000,
            date: DateTime(2026, 5),
          ),
        ],
      );

      expect(find.text('Not enough history yet'), findsOneWidget);
    });

    testWidgets('renders on a small phone without overflowing', (
      tester,
    ) async {
      await ReportsHarness.pump(
        tester,
        route: Routes.reportsCompare,
        size: ReportsHarness.smallPhone,
      );
      await ReportsHarness.scrollTo(tester, find.text('By category'));

      expect(tester.takeException(), isNull);
    });
  });
}
