import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/domain/dashboard_data.dart';
import 'package:lifepilot_finance/features/dashboard/domain/dashboard_period.dart';

/// The mock stands where the reporting API will stand, so its figures have
/// to be internally consistent the way that API's would be.
///
/// These tests do the arithmetic the app is forbidden from doing. That is
/// the point: the consistency is checked once, here, instead of being
/// recomputed on every frame by a widget.
void main() {
  final repository = MockDashboardRepository(delay: Duration.zero);

  Future<DashboardData> load(DashboardPeriod period) =>
      MockDashboardRepository(delay: Duration.zero).load(period);

  group('figures add up', () {
    for (final period in [
      const DashboardPeriod.thisMonth(),
      const DashboardPeriod.thisYear(),
      DashboardPeriod.custom(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 26),
      ),
    ]) {
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

        test('budget remaining is limit minus spent', () async {
          final budget = (await load(period)).budget!;

          expect(
            budget.remaining.minorUnits,
            budget.limit.minorUnits - budget.spent.minorUnits,
          );
        });

        test('budget ratio matches spent over limit', () async {
          final budget = (await load(period)).budget!;

          expect(
            budget.ratio,
            closeTo(budget.spent.minorUnits / budget.limit.minorUnits, 0.01),
          );
        });

        test('budget spending equals the period expenses', () async {
          // A budget card reporting a different number from the Money out
          // card directly above it is the kind of inconsistency a reviewer
          // notices immediately and cannot unsee.
          final data = await load(period);

          expect(data.budget!.spent.minorUnits, data.expenses.minorUnits);
        });

        test('budget status matches the ratio', () async {
          final budget = (await load(period)).budget!;

          final expected = switch (budget.ratio) {
            > 1.0 => BudgetStatus.overBudget,
            >= 0.8 => BudgetStatus.closeToLimit,
            _ => BudgetStatus.comfortable,
          };

          expect(budget.status, expected);
        });

        test('savings previews are consistent with their own totals', () async {
          final savings = (await load(period)).savings!;

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
          final savings = (await load(period)).savings!;
          expect(savings.previews.length, lessThanOrEqualTo(savings.activeGoals));
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

  group('recent transactions', () {
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
  });

  group('the year view keeps its gaps', () {
    test('months with no records are null, not zero', () async {
      // A month of no data drawn as zero is a lie the chart tells silently.
      final trend = (await load(const DashboardPeriod.thisYear())).trend;

      expect(trend.labels, hasLength(12));
      expect(trend.income[trend.labels.indexOf('Aug')], isNull);
      expect(trend.expenses[trend.labels.indexOf('Dec')], isNull);
    });
  });

  group('custom range', () {
    test('bucket labels come from the chosen dates', () async {
      final data = await load(
        DashboardPeriod.custom(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 29),
        ),
      );

      expect(data.trend.labels.first, '1 Mar');
      expect(data.trend.labels, hasLength(4));
    });

    test('describe names the range', () {
      final period = DashboardPeriod.custom(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 29),
      );

      expect(period.describe(), '1 Mar – 29 Mar');
    });
  });

  group('empty mode', () {
    test('reports nothing rather than zeroes dressed as data', () async {
      repository.mode = MockDataMode.empty;
      final data = await repository.load(const DashboardPeriod.thisMonth());

      expect(data.isEmpty, isTrue);
      expect(data.recentTransactions, isEmpty);
      expect(data.budget, isNull);
      expect(data.savings, isNull);
      expect(data.trend.isEmpty, isTrue);
    });

    test('switching back reports the account again', () async {
      repository.mode = MockDataMode.empty;
      await repository.load(const DashboardPeriod.thisMonth());

      repository.mode = MockDataMode.populated;
      final data = await repository.load(const DashboardPeriod.thisMonth());

      expect(data.isEmpty, isFalse);
    });
  });

  group('periods differ', () {
    test('the year reports more than the month', () async {
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
}
