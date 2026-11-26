import '../../../core/money/money.dart';
import '../../transactions/domain/date_labels.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../domain/report_data.dart';
import '../domain/report_period.dart';
import '../domain/report_repository.dart';

/// Turns recorded transactions into reports.
///
/// ## It reads the transaction repository rather than inventing figures
///
/// A reports screen whose numbers disagree with the transaction list is
/// worse than no reports screen: the user cannot tell which to believe.
/// So this derives everything from the same records Phase 05 shows, which
/// also makes drill-down real — tapping a category opens the transactions
/// that produced it, not a plausible-looking stand-in.
///
/// ## It is the second file allowed to add up money
///
/// Architecture Rule 1 keeps financial arithmetic out of the Flutter app,
/// because a client that computes its own totals will drift from the
/// Python reporting layer over the conventions that layer encodes. This
/// class plays that layer while the data is mocked: everything above
/// [ReportRepository] receives figures already computed.
///
/// Phase 13 replaces it with calls to the real reporting API and the
/// arithmetic goes with it. `test/transactions/architecture_test.dart`
/// fails the build if any of it leaks upward in the meantime.
class MockReportRepository implements ReportRepository {
  MockReportRepository({
    required this.transactions,
    required this.now,
    this.delay = const Duration(milliseconds: 300),
  });

  final TransactionRepository transactions;
  final DateTime Function() now;

  /// Long enough that the loading state is real. Tests pass zero.
  final Duration delay;

  @override
  Future<ReportData> report(ReportPeriod period) async {
    await Future<void>.delayed(delay);

    final records = await _inRange(period.start, period.end);
    if (records.isEmpty) {
      return ReportData.empty;
    }

    var income = 0;
    var expenses = 0;
    final byCategory = <String, _CategoryTally>{};

    for (final record in records) {
      final minorUnits = record.amount.minorUnits;
      if (minorUnits >= 0) {
        income += minorUnits;
        continue;
      }

      final magnitude = -minorUnits;
      expenses += magnitude;
      final tally = byCategory.putIfAbsent(
        record.categoryId,
        () => _CategoryTally(record.categoryLabel),
      );
      tally.total += magnitude;
      tally.count++;
    }

    return ReportData(
      income: Money(income),
      expenses: Money(expenses),
      net: Money(income - expenses),
      transactionCount: records.length,
      categories: _rank(byCategory, expenses),
      points: _bucket(period, records),
      metrics: _metrics(
        period: period,
        records: records,
        income: income,
        expenses: expenses,
        categories: _rank(byCategory, expenses),
      ),
      isInProgress: period.isInProgress(now()),
    );
  }

  @override
  Future<List<int>> yearsWithData() async {
    final all = await _inRange(DateTime(1970), now());
    final years = <int>{for (final record in all) record.date.year};
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<YearComparison> compareYears(int earlier, int later) async {
    await Future<void>.delayed(delay);

    final earlierTotals = await _yearTotals(earlier);
    final laterTotals = await _yearTotals(later);
    final today = DateLabels.dayOf(now());

    /// A year is only comparable once it has ended and has records in it.
    /// Measuring a finished year against four months of another produces
    /// a confident number that means nothing.
    bool complete(int year, _YearTotals totals) =>
        totals.count > 0 && DateTime(year, 12, 31).isBefore(today);

    return YearComparison(
      earlierYear: earlier,
      laterYear: later,
      lines: [
        _line('Income', earlierTotals.income, laterTotals.income, true),
        _line('Spending', earlierTotals.expenses, laterTotals.expenses, false),
        _line('Net movement', earlierTotals.net, laterTotals.net, true),
      ],
      categories: _compareCategories(earlierTotals, laterTotals),
      earlierIsComplete: complete(earlier, earlierTotals),
      laterIsComplete: complete(later, laterTotals),
    );
  }

  // ------------------------------------------------------------- reading

  Future<List<Transaction>> _inRange(DateTime from, DateTime to) async {
    final view = await transactions.list(
      TransactionFilter(from: from, to: to),
    );
    return [for (final group in view.groups) ...group.transactions];
  }

  // --------------------------------------------------------- the analysis

  List<CategorySlice> _rank(
    Map<String, _CategoryTally> byCategory,
    int totalExpenses,
  ) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return [
      for (var i = 0; i < entries.length; i++)
        CategorySlice(
          categoryId: entries[i].key,
          label: entries[i].value.label,
          amount: Money(entries[i].value.total),
          // Guarded: a window with income but no spending would divide by
          // zero, and a NaN share paints a bar of indeterminate length.
          share: totalExpenses == 0
              ? 0
              : entries[i].value.total / totalExpenses,
          rank: i + 1,
          transactionCount: entries[i].value.count,
        ),
    ];
  }

  /// Trend buckets sized to the window.
  ///
  /// A year gets twelve months, a month gets its weeks, a week gets its
  /// days. A single day gets nothing: one bucket is a figure, not a
  /// trend, and a chart with one bar invites a comparison there is
  /// nothing to compare against.
  List<ReportPoint> _bucket(ReportPeriod period, List<Transaction> records) {
    switch (period.kind) {
      case ReportPeriodKind.today:
        return const [];

      case ReportPeriodKind.year:
        return [
          for (var month = 1; month <= 12; month++)
            _pointFor(
              label: _shortMonths[month - 1],
              monthOfYear: month,
              matching: records.where(
                (r) => r.date.month == month && r.date.year == period.anchor.year,
              ),
              // Months that have not happened yet are a gap, not a zero.
              isPossible: !DateTime(
                period.anchor.year,
                month,
              ).isAfter(DateTime(now().year, now().month)),
            ),
        ];

      case ReportPeriodKind.week:
        return [
          for (var offset = 0; offset < 7; offset++)
            () {
              final day = period.start.add(Duration(days: offset));
              return _pointFor(
                label: _weekdays[day.weekday - 1],
                matching: records.where(
                  (r) => DateLabels.dayOf(r.date) == day,
                ),
                isPossible: !day.isAfter(DateLabels.dayOf(now())),
              );
            }(),
        ];

      case ReportPeriodKind.month:
      case ReportPeriodKind.custom:
        return _evenBuckets(period, records);
    }
  }

  /// Up to six even buckets across the window, for months and custom
  /// ranges where there is no natural unit.
  List<ReportPoint> _evenBuckets(
    ReportPeriod period,
    List<Transaction> records,
  ) {
    final days = period.dayCount;
    final bucketCount = days <= 1 ? 1 : (days <= 10 ? days : 6);
    final span = (days / bucketCount).ceil();

    return [
      for (var i = 0; i < bucketCount; i++)
        () {
          final start = period.start.add(Duration(days: span * i));
          if (start.isAfter(period.end)) {
            return ReportPoint(
              label: DateLabels.short(start),
              income: null,
              expenses: null,
            );
          }
          var stop = start.add(Duration(days: span - 1));
          if (stop.isAfter(period.end)) stop = period.end;

          // The month is dropped when the whole window sits inside one:
          // six labels of "1–5 Nov" collide on a phone, and the period
          // title directly above already says which month it is.
          final spansMonths = period.start.month != period.end.month ||
              period.start.year != period.end.year;
          final suffix = spansMonths
              ? ' ${_shortMonths[stop.month - 1]}'
              : '';

          return _pointFor(
            label: span == 1
                ? (spansMonths
                      ? DateLabels.short(start)
                      : '${start.day}')
                : '${start.day}–${stop.day}$suffix',
            matching: records.where((r) {
              final day = DateLabels.dayOf(r.date);
              return !day.isBefore(start) && !day.isAfter(stop);
            }),
            isPossible: !start.isAfter(DateLabels.dayOf(now())),
          );
        }(),
    ];
  }

  ReportPoint _pointFor({
    required String label,
    required Iterable<Transaction> matching,
    required bool isPossible,
    int? monthOfYear,
  }) {
    if (!isPossible) {
      return ReportPoint(
        label: label,
        income: null,
        expenses: null,
        monthOfYear: monthOfYear,
      );
    }

    var income = 0;
    var expenses = 0;
    for (final record in matching) {
      final minorUnits = record.amount.minorUnits;
      if (minorUnits >= 0) {
        income += minorUnits;
      } else {
        expenses += -minorUnits;
      }
    }

    return ReportPoint(
      label: label,
      income: income,
      expenses: expenses,
      monthOfYear: monthOfYear,
    );
  }

  /// The secondary figures, chosen for the window rather than shown all at
  /// once. Four is about the limit before a metric row becomes wallpaper.
  List<ReportMetric> _metrics({
    required ReportPeriod period,
    required List<Transaction> records,
    required int income,
    required int expenses,
    required List<CategorySlice> categories,
  }) {
    final metrics = <ReportMetric>[
      ReportMetric(
        label: 'Transactions',
        value: '${records.length}',
        caption: 'in this period',
      ),
    ];

    if (period.kind == ReportPeriodKind.year) {
      // Elapsed months, not twelve: dividing a part-year by twelve
      // understates every average on it.
      final months = period.isInProgress(now())
          ? now().month
          : 12;
      metrics
        ..add(
          ReportMetric(
            label: 'Average month',
            value: Money(expenses ~/ months).format(),
            caption: 'spending',
          ),
        )
        ..add(
          ReportMetric(
            label: 'Average month',
            value: Money(income ~/ months).format(),
            caption: 'income',
          ),
        );

      final peak = _peakMonth(records);
      if (peak != null) {
        metrics.add(
          ReportMetric(
            label: 'Biggest month',
            value: ReportPeriod.monthName(peak.month),
            caption: Money(peak.amount).format(),
          ),
        );
      }
    } else {
      final days = period.isInProgress(now())
          ? DateLabels.dayOf(now()).difference(period.start).inDays + 1
          : period.dayCount;
      metrics.add(
        ReportMetric(
          label: 'Average day',
          value: Money(expenses ~/ (days < 1 ? 1 : days)).format(),
          caption: 'spending',
        ),
      );

      if (categories.isNotEmpty) {
        metrics.add(
          ReportMetric(
            label: 'Biggest category',
            value: categories.first.label,
            caption: '${categories.first.percent}% of spending',
          ),
        );
      }
    }

    return metrics;
  }

  _PeakMonth? _peakMonth(List<Transaction> records) {
    final byMonth = <int, int>{};
    for (final record in records) {
      final minorUnits = record.amount.minorUnits;
      if (minorUnits >= 0) continue;
      byMonth[record.date.month] =
          (byMonth[record.date.month] ?? 0) + -minorUnits;
    }
    if (byMonth.isEmpty) return null;

    var bestMonth = 0;
    var bestAmount = -1;
    for (final entry in byMonth.entries) {
      if (entry.value > bestAmount) {
        bestMonth = entry.key;
        bestAmount = entry.value;
      }
    }
    return _PeakMonth(bestMonth, bestAmount);
  }

  // ------------------------------------------------------- comparison

  Future<_YearTotals> _yearTotals(int year) async {
    final records = await _inRange(DateTime(year), DateTime(year, 12, 31));

    var income = 0;
    var expenses = 0;
    final byCategory = <String, _CategoryTally>{};

    for (final record in records) {
      final minorUnits = record.amount.minorUnits;
      if (minorUnits >= 0) {
        income += minorUnits;
        continue;
      }
      final magnitude = -minorUnits;
      expenses += magnitude;
      final tally = byCategory.putIfAbsent(
        record.categoryId,
        () => _CategoryTally(record.categoryLabel),
      );
      tally.total += magnitude;
      tally.count++;
    }

    return _YearTotals(
      income: income,
      expenses: expenses,
      net: income - expenses,
      count: records.length,
      byCategory: byCategory,
    );
  }

  ComparisonLine _line(
    String label,
    int earlier,
    int later,
    bool higherIsBetter,
  ) => ComparisonLine(
    label: label,
    earlier: Money(earlier),
    later: Money(later),
    delta: Money(later - earlier),
    // Null rather than infinity when there is nothing to grow from.
    // "Up 100%" from zero is not a fact about the user's money.
    percentChange: earlier == 0 ? null : (later - earlier) / earlier,
    higherIsBetter: higherIsBetter,
  );

  List<ComparisonLine> _compareCategories(
    _YearTotals earlier,
    _YearTotals later,
  ) {
    final ids = {...earlier.byCategory.keys, ...later.byCategory.keys};

    final lines = [
      for (final id in ids)
        _line(
          later.byCategory[id]?.label ??
              earlier.byCategory[id]?.label ??
              id,
          earlier.byCategory[id]?.total ?? 0,
          later.byCategory[id]?.total ?? 0,
          false,
        ),
    ]..sort((a, b) => b.later.minorUnits.compareTo(a.later.minorUnits));

    return lines;
  }

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
}

class _CategoryTally {
  _CategoryTally(this.label);

  final String label;
  int total = 0;
  int count = 0;
}

class _YearTotals {
  const _YearTotals({
    required this.income,
    required this.expenses,
    required this.net,
    required this.count,
    required this.byCategory,
  });

  final int income;
  final int expenses;
  final int net;
  final int count;
  final Map<String, _CategoryTally> byCategory;
}

class _PeakMonth {
  const _PeakMonth(this.month, this.amount);

  final int month;
  final int amount;
}
