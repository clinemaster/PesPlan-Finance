import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_filter.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

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

MockReportRepository reportsOver(List<Transaction> seed) =>
    MockReportRepository(
      transactions: MockTransactionRepository(
        now: () => today,
        seed: seed,
        delay: Duration.zero,
      ),
      now: () => today,
      delay: Duration.zero,
    );

/// The full seeded history, three years of it.
MockReportRepository get seededReports => MockReportRepository(
  transactions: MockTransactionRepository(
    now: () => today,
    delay: Duration.zero,
  ),
  now: () => today,
  delay: Duration.zero,
);

void main() {
  group('totals', () {
    test('sum each side and net them', () async {
      final repository = reportsOver([
        make(
          id: '1',
          type: TransactionType.income,
          magnitude: 900000,
          date: DateTime(2026, 11, 10),
        ),
        make(
          id: '2',
          type: TransactionType.expense,
          magnitude: 250000,
          date: DateTime(2026, 11, 11),
        ),
        make(
          id: '3',
          type: TransactionType.expense,
          magnitude: 50000,
          date: DateTime(2026, 11, 12),
        ),
      ]);

      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.income.minorUnits, 900000);
      expect(report.expenses.minorUnits, 300000);
      expect(report.net.minorUnits, 600000);
      expect(report.transactionCount, 3);
    });

    test('only count what falls inside the window', () async {
      final repository = reportsOver([
        make(
          id: 'in',
          type: TransactionType.expense,
          magnitude: 1000,
          date: DateTime(2026, 11, 15),
        ),
        make(
          id: 'out',
          type: TransactionType.expense,
          magnitude: 9999,
          date: DateTime(2026, 10, 15),
        ),
      ]);

      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.transactionCount, 1);
      expect(report.expenses.minorUnits, 1000);
    });

    test('an empty window reports empty rather than zeroes', () async {
      final report = await reportsOver(
        const [],
      ).report(ReportPeriod.monthOf(2026, 11));

      expect(report.isEmpty, isTrue);
      expect(report.categories, isEmpty);
      expect(report.points, isEmpty);
    });
  });

  group('category breakdown', () {
    late MockReportRepository repository;

    setUp(() {
      repository = reportsOver([
        make(
          id: '1',
          type: TransactionType.expense,
          magnitude: 600000,
          date: DateTime(2026, 11, 2),
          categoryId: 'housing',
          categoryLabel: 'Housing',
        ),
        make(
          id: '2',
          type: TransactionType.expense,
          magnitude: 300000,
          date: DateTime(2026, 11, 3),
          categoryId: 'food',
          categoryLabel: 'Food',
        ),
        make(
          id: '3',
          type: TransactionType.expense,
          magnitude: 100000,
          date: DateTime(2026, 11, 4),
          categoryId: 'food',
          categoryLabel: 'Food',
        ),
        make(
          id: '4',
          type: TransactionType.income,
          magnitude: 500000,
          date: DateTime(2026, 11, 5),
          categoryId: 'salary',
          categoryLabel: 'Salary',
        ),
      ]);
    });

    test('ranks categories by spending, largest first', () async {
      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.categories.map((c) => c.label), ['Housing', 'Food']);
      expect(report.categories.first.rank, 1);
      expect(report.categories[1].rank, 2);
    });

    test('shares are of total spending and add to one', () async {
      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.categories.first.share, closeTo(0.6, 0.001));
      expect(report.categories[1].share, closeTo(0.4, 0.001));
      expect(
        report.categories.fold<double>(0, (sum, c) => sum + c.share),
        closeTo(1.0, 0.001),
      );
    });

    test('income is not a spending category', () async {
      // Salary in a "where it went" breakdown would be nonsense, and
      // would wreck every share below it.
      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.categories.map((c) => c.categoryId), isNot(contains('salary')));
    });

    test('counts the entries behind each category', () async {
      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.categories[1].transactionCount, 2);
    });

    test('a window with income but no spending does not divide by zero',
        () async {
      final repository = reportsOver([
        make(
          id: '1',
          type: TransactionType.income,
          magnitude: 100,
          date: DateTime(2026, 11, 2),
          categoryId: 'salary',
          categoryLabel: 'Salary',
        ),
      ]);

      final report = await repository.report(ReportPeriod.monthOf(2026, 11));

      expect(report.categories, isEmpty);
      expect(report.expenses.minorUnits, 0);
    });
  });

  group('trend buckets', () {
    test('a year has twelve months, labelled and tappable', () async {
      final report = await seededReports.report(ReportPeriod.yearOf(2025));

      expect(report.points, hasLength(12));
      expect(report.points.first.label, 'Jan');
      expect(report.points.last.label, 'Dec');
      expect(report.points.first.monthOfYear, 1);
      expect(report.points.last.monthOfYear, 12);
    });

    test('months that have not happened are gaps, not zeroes', () async {
      // A future month drawn as zero spending is a lie the chart tells
      // silently.
      final report = await seededReports.report(ReportPeriod.yearOf(2026));

      final december = report.points[11];
      expect(december.income, isNull);
      expect(december.expenses, isNull);
      expect(december.isEmpty, isTrue);
    });

    test('a week has seven days, Monday first', () async {
      final report = await seededReports.report(ReportPeriod.week(today));

      expect(report.points, hasLength(7));
      expect(report.points.first.label, 'Mon');
      expect(report.points.last.label, 'Sun');
    });

    test('a single day has no trend at all', () async {
      final report = await seededReports.report(ReportPeriod.today(today));

      expect(report.points, isEmpty);
    });

    test('a month is bucketed into a readable number of columns', () async {
      final report = await seededReports.report(
        ReportPeriod.monthOf(2026, 10),
      );

      expect(report.points.length, lessThanOrEqualTo(6));
      expect(report.points, isNotEmpty);
    });

    test('year buckets sum to the year total', () async {
      final report = await seededReports.report(ReportPeriod.yearOf(2025));

      var expenses = 0;
      for (final point in report.points) {
        expenses += point.expenses ?? 0;
      }
      expect(expenses, report.expenses.minorUnits);
    });
  });

  group('metrics', () {
    test('a month reports an average day and a biggest category', () async {
      final report = await seededReports.report(
        ReportPeriod.monthOf(2026, 10),
      );

      final labels = report.metrics.map((m) => m.label);
      expect(labels, contains('Transactions'));
      expect(labels, contains('Average day'));
      expect(labels, contains('Biggest category'));
    });

    test('a year reports monthly averages and the biggest month', () async {
      final report = await seededReports.report(ReportPeriod.yearOf(2025));

      final labels = report.metrics.map((m) => m.label).toList();
      expect(labels.where((l) => l == 'Average month'), hasLength(2));
      expect(labels, contains('Biggest month'));
    });

    test('a part-year averages over elapsed months, not twelve', () async {
      // Dividing eleven months of spending by twelve understates every
      // average on the screen.
      final partial = await seededReports.report(ReportPeriod.yearOf(2026));
      final complete = await seededReports.report(ReportPeriod.yearOf(2025));

      expect(partial.isInProgress, isTrue);
      expect(complete.isInProgress, isFalse);
    });

    test('metrics never exceed four, so the row stays readable', () async {
      for (final period in [
        ReportPeriod.today(today),
        ReportPeriod.week(today),
        ReportPeriod.monthOf(2026, 10),
        ReportPeriod.yearOf(2025),
      ]) {
        final report = await seededReports.report(period);
        expect(report.metrics.length, lessThanOrEqualTo(4));
      }
    });
  });

  group('years with data', () {
    test('lists only years that hold records, newest first', () async {
      final years = await seededReports.yearsWithData();

      expect(years, isNotEmpty);
      expect(years.first, 2026);
      expect(years, orderedEquals(years.toList()..sort((a, b) => b.compareTo(a))));
      expect(years.toSet().length, years.length, reason: 'no duplicates');
    });
  });

  group('year comparison', () {
    test('reports income, spending and net', () async {
      final comparison = await seededReports.compareYears(2024, 2025);

      expect(
        comparison.lines.map((l) => l.label),
        ['Income', 'Spending', 'Net movement'],
      );
    });

    test('the delta is later minus earlier', () async {
      final comparison = await seededReports.compareYears(2024, 2025);
      final income = comparison.lines.first;

      expect(
        income.delta.minorUnits,
        income.later.minorUnits - income.earlier.minorUnits,
      );
    });

    test('income rising is good news, spending rising is not', () async {
      final comparison = await seededReports.compareYears(2024, 2025);

      expect(comparison.lines[0].higherIsBetter, isTrue);
      expect(comparison.lines[1].higherIsBetter, isFalse);
    });

    test('a percentage from zero is withheld, not invented', () async {
      // "Up 100%" from nothing is not a fact about anyone's money.
      final repository = reportsOver([
        make(
          id: 'only',
          type: TransactionType.income,
          magnitude: 500,
          date: DateTime(2025, 6, 1),
        ),
      ]);

      final comparison = await repository.compareYears(2024, 2025);
      expect(comparison.lines.first.earlier.minorUnits, 0);
      expect(comparison.lines.first.percentChange, isNull);
    });

    test('an unfinished year is flagged as not comparable', () async {
      final comparison = await seededReports.compareYears(2025, 2026);

      expect(comparison.earlierIsComplete, isTrue);
      expect(
        comparison.laterIsComplete,
        isFalse,
        reason: '2026 has not ended',
      );
      expect(comparison.isTrustworthy, isFalse);
    });

    test('two finished years are comparable', () async {
      final comparison = await seededReports.compareYears(2024, 2025);
      expect(comparison.isTrustworthy, isTrue);
    });

    test('categories are compared and sorted by the later year', () async {
      final comparison = await seededReports.compareYears(2024, 2025);

      expect(comparison.categories, isNotEmpty);
      for (var i = 1; i < comparison.categories.length; i++) {
        expect(
          comparison.categories[i - 1].later.minorUnits,
          greaterThanOrEqualTo(comparison.categories[i].later.minorUnits),
        );
      }
    });

    test('a category present in only one year still appears', () async {
      final repository = reportsOver([
        make(
          id: 'a',
          type: TransactionType.expense,
          magnitude: 1000,
          date: DateTime(2024, 6),
          categoryId: 'health',
          categoryLabel: 'Health',
        ),
        make(
          id: 'b',
          type: TransactionType.expense,
          magnitude: 2000,
          date: DateTime(2025, 6),
          categoryId: 'food',
          categoryLabel: 'Food',
        ),
      ]);

      final comparison = await repository.compareYears(2024, 2025);
      expect(comparison.categories.map((c) => c.label), containsAll(
        <String>['Health', 'Food'],
      ));
    });
  });

  group('reports agree with the transactions they came from', () {
    test('a month report matches the transaction list for that month',
        () async {
      // The whole reason reports read the transaction repository: two
      // screens disagreeing about the same month is worse than having
      // only one of them.
      final transactions = MockTransactionRepository(
        now: () => today,
        delay: Duration.zero,
      );
      final reports = MockReportRepository(
        transactions: transactions,
        now: () => today,
        delay: Duration.zero,
      );

      final period = ReportPeriod.monthOf(2026, 10);
      final report = await reports.report(period);
      final listed = await transactions.list(
        TransactionFilter(from: period.start, to: period.end),
      );

      expect(report.income.minorUnits, listed.totals.income.minorUnits);
      expect(report.expenses.minorUnits, listed.totals.expenses.minorUnits);
      expect(report.net.minorUnits, listed.totals.net.minorUnits);
      expect(report.transactionCount, listed.matchCount);
    });
  });

  group('determinism', () {
    test('the same clock produces the same report twice', () async {
      // A reviewer who opens a report, closes it and opens it again must
      // see the same figures. A generator seeded from the system random
      // would not give them that.
      final first = await seededReports.report(ReportPeriod.yearOf(2025));
      final second = await seededReports.report(ReportPeriod.yearOf(2025));

      expect(first.income.minorUnits, second.income.minorUnits);
      expect(first.expenses.minorUnits, second.expenses.minorUnits);
      expect(
        first.categories.map((c) => c.amount.minorUnits),
        second.categories.map((c) => c.amount.minorUnits),
      );
    });
  });
}
