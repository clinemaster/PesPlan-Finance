import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget_progress.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget_status.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';

import 'harness.dart';

final DateTime today = BudgetsHarness.now;

/// The chain, wired as production wires it: budgets read reports, reports
/// read transactions.
MockBudgetRepository budgetsOver({
  List<Budget>? plans,
  List<Transaction>? seed,
  BudgetThresholds thresholds = BudgetThresholds.standard,
}) => MockBudgetRepository(
  reports: MockReportRepository(
    transactions: MockTransactionRepository(
      now: () => today,
      seed: seed,
      delay: Duration.zero,
    ),
    now: () => today,
    delay: Duration.zero,
  ),
  now: () => today,
  seed: plans,
  thresholds: thresholds,
  delay: Duration.zero,
);

Future<BudgetBoard> boardOf({
  List<Budget>? plans,
  List<Transaction>? seed,
  BudgetThresholds thresholds = BudgetThresholds.standard,
}) => budgetsOver(
  plans: plans,
  seed: seed,
  thresholds: thresholds,
).board(year: 2026, month: 11);

void main() {
  group('spending comes from the recorded transactions', () {
    test('a category budget is measured against that category only', () async {
      final board = await boardOf(
        plans: [
          plan(amount: 250000, categoryId: 'food', categoryLabel: 'Food'),
        ],
        seed: [
          spent(id: 'a', amount: 60000),
          spent(id: 'b', amount: 40000),
          spent(
            id: 'c',
            amount: 500000,
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
        ],
      );

      final food = board.categories.single;
      expect(food.spent.minorUnits, 100000);
      expect(food.transactionCount, 2);
    });

    test('an overall budget is measured against everything spent', () async {
      final board = await boardOf(
        plans: [overallPlan(amount: 1000000)],
        seed: [
          spent(id: 'a', amount: 60000),
          spent(
            id: 'b',
            amount: 500000,
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
        ],
      );

      expect(board.overall!.spent.minorUnits, 560000);
    });

    test('a budget with no spending reads zero, not null', () async {
      final board = await boardOf(
        plans: [plan(amount: 250000)],
        seed: const [],
      );

      final food = board.categories.single;
      expect(food.spent.minorUnits, 0);
      expect(food.transactionCount, 0);
      expect(food.status, BudgetStatus.onTrack);
    });

    test('it agrees with the report for the same month', () async {
      // The whole reason this repository reads reports: a Budgets screen
      // saying Food cost 50,000 while Reports says 106,900 for the same
      // month is the inconsistency the chain exists to prevent.
      final transactions = MockTransactionRepository(
        now: () => today,
        delay: Duration.zero,
      );
      final reports = MockReportRepository(
        transactions: transactions,
        now: () => today,
        delay: Duration.zero,
      );
      final budgets = MockBudgetRepository(
        reports: reports,
        now: () => today,
        delay: Duration.zero,
      );

      final board = await budgets.board(year: 2026, month: 11);
      final report = await reports.report(ReportPeriod.monthOf(2026, 11));

      expect(board.totalSpent.minorUnits, report.expenses.minorUnits);
      expect(board.overall!.spent.minorUnits, report.expenses.minorUnits);

      final food = board.categories.firstWhere(
        (c) => c.budget.categoryId == 'food',
      );
      final foodInReports = report.categories.firstWhere(
        (c) => c.categoryId == 'food',
      );
      expect(food.spent.minorUnits, foodInReports.amount.minorUnits);
    });
  });

  group('the arithmetic arrives computed', () {
    test('remaining is the limit less what was spent', () async {
      final board = await boardOf(
        plans: [plan(amount: 250000)],
        seed: [spent(amount: 90000)],
      );

      expect(board.categories.single.remaining.minorUnits, 160000);
    });

    test('remaining goes negative once the limit is passed', () async {
      final board = await boardOf(
        plans: [plan(amount: 100000)],
        seed: [spent(amount: 130000)],
      );

      final food = board.categories.single;
      expect(food.remaining.minorUnits, -30000);
      expect(food.isOver, isTrue);
    });

    test('overspend is the same figure as a positive magnitude', () async {
      // Carried as its own field rather than negated in the domain: the
      // app has no financial engine, and the architecture test fails the
      // build when one appears.
      final board = await boardOf(
        plans: [plan(amount: 100000)],
        seed: [spent(amount: 130000)],
      );

      expect(board.categories.single.overspend.minorUnits, 30000);
    });

    test('overspend is zero while within the limit', () async {
      final board = await boardOf(
        plans: [plan(amount: 100000)],
        seed: [spent(amount: 40000)],
      );

      expect(board.categories.single.overspend.minorUnits, 0);
    });

    test('ratio and percent describe the same share', () async {
      final board = await boardOf(
        plans: [plan(amount: 200000)],
        seed: [spent(amount: 150000)],
      );

      final food = board.categories.single;
      expect(food.ratio, closeTo(0.75, 0.0001));
      expect(food.percent, 75);
    });

    test('status follows the ratio through every level', () async {
      Future<BudgetStatus> statusFor(int spending) async {
        final board = await boardOf(
          plans: [plan(amount: 100000)],
          seed: [spent(amount: spending)],
        );
        return board.categories.single.status;
      }

      expect(await statusFor(10000), BudgetStatus.onTrack);
      expect(await statusFor(80000), BudgetStatus.approaching);
      expect(await statusFor(95000), BudgetStatus.nearLimit);
      expect(await statusFor(120000), BudgetStatus.over);
    });

    test('injected thresholds change the level, not the figures', () async {
      final board = await boardOf(
        plans: [plan(amount: 100000)],
        seed: [spent(amount: 60000)],
        thresholds: const BudgetThresholds(approaching: 0.5, nearLimit: 0.7),
      );

      final food = board.categories.single;
      expect(food.status, BudgetStatus.approaching);
      expect(food.spent.minorUnits, 60000);
    });
  });

  group('the board', () {
    test('puts the most pressing category first', () async {
      // Sorted by pressure rather than size, so the one category over its
      // limit is not buried under four that are fine.
      final board = await boardOf(
        plans: [
          plan(
            amount: 500000,
            id: 'housing',
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
          plan(
            amount: 100000,
            id: 'food',
            categoryId: 'food',
            categoryLabel: 'Food',
          ),
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
          spent(id: 'b', amount: 120000),
          spent(
            id: 'c',
            amount: 40000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      expect(board.categories.map((c) => c.budget.categoryId), [
        'food',
        'transport',
        'housing',
      ]);
    });

    test('totals only the category budgets, not the overall one', () async {
      // A user can budget 300,000 across three categories while their
      // overall limit is 800,000, and both numbers are true — adding the
      // overall one in would double-count the month.
      final board = await boardOf(
        plans: [
          overallPlan(amount: 800000),
          plan(amount: 200000, id: 'food'),
          plan(
            amount: 100000,
            id: 'transport',
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
        seed: const [],
      );

      expect(board.totalBudgeted.minorUnits, 300000);
      expect(board.overall!.budget.amount.minorUnits, 800000);
    });

    test('reports spending in categories nobody budgeted', () async {
      final board = await boardOf(
        plans: [plan(amount: 200000, id: 'food')],
        seed: [
          spent(id: 'a', amount: 50000),
          spent(
            id: 'b',
            amount: 70000,
            categoryId: 'bills',
            categoryLabel: 'Bills',
          ),
          spent(
            id: 'c',
            amount: 30000,
            categoryId: 'health',
            categoryLabel: 'Health',
          ),
        ],
      );

      expect(board.unbudgetedSpending.minorUnits, 100000);
      expect(board.hasUnbudgetedSpending, isTrue);
    });

    test(
      'reports no unbudgeted spending when every shilling is planned',
      () async {
        final board = await boardOf(
          plans: [plan(amount: 200000, id: 'food')],
          seed: [spent(amount: 50000)],
        );

        expect(board.unbudgetedSpending.minorUnits, 0);
        expect(board.hasUnbudgetedSpending, isFalse);
      },
    );

    test('is empty when the month has no plans', () async {
      final board = await boardOf(plans: const []);

      expect(board.isEmpty, isTrue);
      expect(board.overall, isNull);
      expect(board.categories, isEmpty);
    });

    test('is not empty with plans but no spending', () async {
      // A plan with nothing spent against it is a budget, not an absence
      // of one — the empty state would be a lie.
      final board = await boardOf(
        plans: [plan(amount: 200000)],
        seed: const [],
      );

      expect(board.isEmpty, isFalse);
    });

    test('ignores plans belonging to another month', () async {
      final board = await boardOf(
        plans: [
          plan(amount: 200000, id: 'nov'),
          plan(amount: 999000, id: 'oct', month: 10),
          plan(amount: 999000, id: 'last-year', year: 2025),
        ],
        seed: const [],
      );

      expect(board.categories, hasLength(1));
      expect(board.categories.single.budget.id, 'nov');
    });

    test('a zero limit does not produce a NaN ratio', () async {
      // The validator refuses zero; this is for a budget stored by an
      // older build, where a NaN would paint a bar of indeterminate
      // length.
      final board = await boardOf(
        plans: [plan(amount: 0)],
        seed: [spent(amount: 10000)],
      );

      final food = board.categories.single;
      expect(food.ratio, 0);
      expect(food.percent, 0);
      expect(food.status, BudgetStatus.onTrack);
    });
  });

  group('reading and writing', () {
    test('forMonth returns only that month', () async {
      final repository = budgetsOver(
        plans: [
          plan(amount: 1000, id: 'nov'),
          plan(amount: 1000, id: 'oct', month: 10),
        ],
      );

      final november = await repository.forMonth(year: 2026, month: 11);
      expect(november.map((b) => b.id), ['nov']);
    });

    test('byId finds a budget, and misses honestly', () async {
      final repository = budgetsOver(plans: [plan(amount: 1000, id: 'food')]);

      expect((await repository.byId('food'))?.id, 'food');
      expect(await repository.byId('nope'), isNull);
    });

    test('create adds a plan the board then measures', () async {
      final repository = budgetsOver(
        plans: const [],
        seed: [spent(amount: 90000)],
      );

      await repository.create(plan(amount: 100000, id: 'new'));
      final board = await repository.board(year: 2026, month: 11);

      expect(repository.all, hasLength(1));
      expect(board.categories.single.spent.minorUnits, 90000);
      expect(board.categories.single.status, BudgetStatus.nearLimit);
    });

    test('update replaces in place and keeps the order', () async {
      final repository = budgetsOver(
        plans: [
          plan(amount: 100000, id: 'food'),
          plan(
            amount: 50000,
            id: 'transport',
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      await repository.update(
        plan(amount: 400000, id: 'food', description: 'Bigger plan'),
      );

      expect(repository.all.map((b) => b.id), ['food', 'transport']);
      expect(repository.all.first.amount.minorUnits, 400000);
      expect(repository.all.first.description, 'Bigger plan');
    });

    test('update refuses a budget it does not hold', () async {
      final repository = budgetsOver(plans: const []);

      expect(
        () => repository.update(plan(amount: 1000, id: 'ghost')),
        throwsStateError,
      );
    });

    test('delete removes it from the board', () async {
      final repository = budgetsOver(plans: [plan(amount: 1000, id: 'food')]);

      await repository.delete('food');
      final board = await repository.board(year: 2026, month: 11);

      expect(repository.all, isEmpty);
      expect(board.isEmpty, isTrue);
    });

    test('new ids are unique', () async {
      final repository = budgetsOver(plans: const []);

      final ids = {for (var i = 0; i < 50; i++) repository.newId()};
      expect(ids, hasLength(50));
    });
  });

  group('the seed', () {
    test(
      'describes the current month, so the screen opens with data',
      () async {
        final repository = budgetsOver();
        final board = await repository.board(year: 2026, month: 11);

        expect(board.overall, isNotNull);
        expect(board.categories, isNotEmpty);
        expect(
          repository.all.every((b) => b.year == 2026 && b.month == 11),
          isTrue,
        );
      },
    );

    test('opens on a real mix rather than all green or all alarming', () async {
      // A review of this screen is worthless if every bar is comfortable.
      final board = await budgetsOver().board(year: 2026, month: 11);
      final levels = board.categories.map((c) => c.status).toSet();

      expect(levels, hasLength(greaterThan(1)));
      expect(
        board.categories.any((c) => c.status.needsAttention),
        isTrue,
        reason: 'at least one category should warrant attention',
      );
    });

    test('holds exactly one overall budget', () async {
      final repository = budgetsOver();
      expect(repository.all.where((b) => b.isOverall), hasLength(1));
    });

    test('budgets no category twice', () async {
      final repository = budgetsOver();
      final categories = [
        for (final budget in repository.all.where((b) => !b.isOverall))
          budget.categoryId,
      ];

      expect(categories.toSet(), hasLength(categories.length));
    });
  });
}
