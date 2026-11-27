import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/domain/dashboard_data.dart';
import 'package:lifepilot_finance/features/dashboard/domain/dashboard_period.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

/// The whole chain, wired as production wires it: the dashboard reads
/// reports, reports read transactions.
MockDashboardRepository dashboardOver([List<Transaction>? seed]) {
  final transactions = MockTransactionRepository(
    now: () => today,
    seed: seed,
    delay: Duration.zero,
  );
  final reports = MockReportRepository(
    transactions: transactions,
    now: () => today,
    delay: Duration.zero,
  );
  return MockDashboardRepository(
    reports: reports,
    transactions: transactions,
    budgets: MockBudgetRepository(
      reports: reports,
      now: () => today,
      delay: Duration.zero,
    ),
    now: () => today,
    delay: Duration.zero,
  );
}

Future<DashboardData> load(DashboardPeriod period) =>
    dashboardOver().load(period);

void main() {
  final periods = [
    const DashboardPeriod.thisMonth(),
    const DashboardPeriod.thisYear(),
    DashboardPeriod.custom(
      start: DateTime(2026, 11),
      end: DateTime(2026, 11, 26),
    ),
  ];

  group('figures add up', () {
    for (final period in periods) {
      group(period.label, () {
        test('net is income minus expenses', () async {
          final data = await load(period);

          expect(
            data.net.minorUnits,
            data.income.minorUnits - data.expenses.minorUnits,
            reason: 'the headline figure must match its own parts',
          );
        });

        test('trend buckets sum to the period totals', () async {
          final data = await load(period);

          var income = 0;
          var expenses = 0;
          for (var i = 0; i < data.trend.labels.length; i++) {
            income += data.trend.income[i] ?? 0;
            expenses += data.trend.expenses[i] ?? 0;
          }

          expect(income, data.income.minorUnits);
          expect(expenses, data.expenses.minorUnits);
        });

        test('trend series are the same length as their labels', () async {
          final data = await load(period);

          expect(data.trend.income.length, data.trend.labels.length);
          expect(data.trend.expenses.length, data.trend.labels.length);
        });

        test('exactly five recent transactions', () async {
          expect((await load(period)).recentTransactions, hasLength(5));
        });

        test('the period is not reported as empty', () async {
          expect((await load(period)).isEmpty, isFalse);
        });
      });
    }
  });

  group('the dashboard agrees with reports', () {
    // The reason this repository was rewritten: with a Reports entry in
    // the dashboard header, two screens one tap apart were reporting
    // different figures for the same month.
    for (final (label, dashboardPeriod, reportPeriod) in [
      ('this month', const DashboardPeriod.thisMonth(), null),
      ('this year', const DashboardPeriod.thisYear(), null),
    ]) {
      test('for $label', () async {
        final transactions = MockTransactionRepository(
          now: () => today,
          delay: Duration.zero,
        );
        final reports = MockReportRepository(
          transactions: transactions,
          now: () => today,
          delay: Duration.zero,
        );
        final dashboard = MockDashboardRepository(
          reports: reports,
          transactions: transactions,
          budgets: MockBudgetRepository(
            reports: reports,
            now: () => today,
            delay: Duration.zero,
          ),
          now: () => today,
          delay: Duration.zero,
        );

        final onDashboard = await dashboard.load(dashboardPeriod);
        final inReports = await reports.report(
          reportPeriod ??
              (dashboardPeriod.kind == PeriodKind.thisMonth
                  ? ReportPeriod.month(today)
                  : ReportPeriod.year(today)),
        );

        expect(onDashboard.income.minorUnits, inReports.income.minorUnits);
        expect(onDashboard.expenses.minorUnits, inReports.expenses.minorUnits);
        expect(onDashboard.net.minorUnits, inReports.net.minorUnits);
      });
    }
  });

  group('budget', () {
    test(
      'is shown for a month, where a monthly limit means something',
      () async {
        final budget = (await load(const DashboardPeriod.thisMonth())).budget;
        expect(budget, isNotNull);
      },
    );

    test(
      'is withheld for a year, which a monthly limit does not describe',
      () async {
        // The authored version scaled the limit by twelve and still called
        // the card "Monthly budget", which was never honest.
        expect((await load(const DashboardPeriod.thisYear())).budget, isNull);
      },
    );

    test('remaining is limit minus spent', () async {
      final budget = (await load(const DashboardPeriod.thisMonth())).budget!;

      expect(
        budget.remaining.minorUnits,
        budget.limit.minorUnits - budget.spent.minorUnits,
      );
    });

    test('ratio matches spent over limit', () async {
      final budget = (await load(const DashboardPeriod.thisMonth())).budget!;

      expect(
        budget.ratio,
        closeTo(budget.spent.minorUnits / budget.limit.minorUnits, 0.01),
      );
    });

    test('spending equals the period expenses', () async {
      // A budget card reporting a different number from the Money out
      // card directly above it is the kind of inconsistency a reviewer
      // notices immediately and cannot unsee.
      final data = await load(const DashboardPeriod.thisMonth());

      expect(data.budget!.spent.minorUnits, data.expenses.minorUnits);
    });

    test('status matches the ratio', () async {
      final budget = (await load(const DashboardPeriod.thisMonth())).budget!;

      final expected = switch (budget.ratio) {
        > 1.0 => BudgetStatus.overBudget,
        >= 0.8 => BudgetStatus.closeToLimit,
        _ => BudgetStatus.comfortable,
      };

      expect(budget.status, expected);
    });
  });

  group('savings', () {
    test('previews are consistent with their own totals', () async {
      final savings = (await load(const DashboardPeriod.thisMonth())).savings!;

      for (final goal in savings.previews) {
        expect(
          goal.ratio,
          closeTo(goal.saved.minorUnits / goal.target.minorUnits, 0.01),
          reason: '${goal.name} progress does not match its amounts',
        );
      }

      expect(
        savings.ratio,
        closeTo(
          savings.totalSaved.minorUnits / savings.totalTarget.minorUnits,
          0.01,
        ),
      );
    });

    test('there are never more previews than goals', () async {
      final savings = (await load(const DashboardPeriod.thisMonth())).savings!;
      expect(savings.previews.length, lessThanOrEqualTo(savings.activeGoals));
    });
  });

  group('recent transactions', () {
    test('are the newest, whatever period is selected', () async {
      // "Recent activity" means recent: switching to the year view is
      // not a request to see January again.
      final month = await load(const DashboardPeriod.thisMonth());
      final year = await load(const DashboardPeriod.thisYear());

      expect(
        month.recentTransactions.map((t) => t.id),
        year.recentTransactions.map((t) => t.id),
      );
    });

    test('carry both signs, so both indicators are exercised', () async {
      final rows = (await load(const DashboardPeriod.thisMonth()))
          .recentTransactions;

      expect(rows.any((r) => r.isIncome), isTrue);
      expect(rows.any((r) => !r.isIncome), isTrue);
    });

    test('ids are unique', () async {
      final rows = (await load(const DashboardPeriod.thisMonth()))
          .recentTransactions;

      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length));
    });

    test('show the category by its label, not its id', () async {
      final rows = (await load(const DashboardPeriod.thisMonth()))
          .recentTransactions;

      expect(rows.map((r) => r.category), isNot(contains('food')));
      expect(rows.map((r) => r.category), contains('Food'));
    });
  });

  group('the year view', () {
    test('months with no records are null, not zero', () async {
      // A month that has not happened drawn as zero spending is a lie
      // the chart tells silently.
      final trend = (await load(const DashboardPeriod.thisYear())).trend;

      expect(trend.labels, hasLength(12));
      expect(trend.income.last, isNull, reason: 'December has not happened');
      expect(trend.expenses.last, isNull);
    });

    test('reports more than the month', () async {
      final month = await load(const DashboardPeriod.thisMonth());
      final year = await load(const DashboardPeriod.thisYear());

      expect(
        year.income.minorUnits,
        greaterThan(month.income.minorUnits),
        reason: 'selecting a period must actually change the figures',
      );
      expect(year.trend.labels.length, greaterThan(month.trend.labels.length));
    });
  });

  group('custom range', () {
    test('describe names the range', () {
      final period = DashboardPeriod.custom(
        start: DateTime(2026, 3),
        end: DateTime(2026, 3, 29),
      );

      expect(period.describe(), '1 Mar – 29 Mar');
    });

    test('covers only the chosen days', () async {
      final data = await load(
        DashboardPeriod.custom(
          start: DateTime(2026, 11, 25),
          end: DateTime(2026, 11, 26),
        ),
      );

      final wholeMonth = await load(const DashboardPeriod.thisMonth());
      expect(
        data.expenses.minorUnits,
        lessThan(wholeMonth.expenses.minorUnits),
      );
    });
  });

  group('empty mode', () {
    test('reports nothing rather than zeroes dressed as data', () async {
      final repository = dashboardOver()..mode = MockDataMode.empty;
      final data = await repository.load(const DashboardPeriod.thisMonth());

      expect(data.isEmpty, isTrue);
      expect(data.recentTransactions, isEmpty);
      expect(data.budget, isNull);
      expect(data.savings, isNull);
      expect(data.trend.isEmpty, isTrue);
    });

    test('switching back reports the account again', () async {
      final repository = dashboardOver()..mode = MockDataMode.empty;
      await repository.load(const DashboardPeriod.thisMonth());

      repository.mode = MockDataMode.populated;
      final data = await repository.load(const DashboardPeriod.thisMonth());

      expect(data.isEmpty, isFalse);
    });

    test(
      'an account with no records reports empty without the switch',
      () async {
        // The real empty state, rather than the review one.
        final data = await dashboardOver(const [])
            .load(const DashboardPeriod.thisMonth());

        expect(data.isEmpty, isTrue);
      },
    );
  });
}
