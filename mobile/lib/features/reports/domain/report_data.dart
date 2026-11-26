import '../../../core/money/money.dart';

/// One category's share of spending in a report.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.label,
    required this.amount,
    required this.share,
    required this.rank,
    required this.transactionCount,
  });

  final String categoryId;
  final String label;
  final Money amount;

  /// 0..1 of total spending. **Computed by the repository**, never by a
  /// widget — Rule 1 covers shares as much as sums.
  final double share;

  /// 1 is the largest. Ranking is what makes a breakdown answer "where
  /// does it all go" rather than just listing categories.
  final int rank;

  final int transactionCount;

  /// Whole percent, for display.
  int get percent => (share * 100).round();
}

/// One bucket on a trend chart.
class ReportPoint {
  const ReportPoint({
    required this.label,
    required this.income,
    required this.expenses,
    this.monthOfYear,
  });

  final String label;

  /// Null means no records in this bucket — a gap, not a zero. The charts
  /// render it as a break, which is the only honest reading.
  final int? income;
  final int? expenses;

  /// Set on annual reports, so tapping a bar can open that month.
  final int? monthOfYear;

  bool get isEmpty => income == null && expenses == null;
}

/// A named figure with enough context to be understood.
///
/// Metrics carry their own explanation because "average daily spending"
/// means nothing without knowing it is over the selected window, and a
/// user who has to guess will guess wrong.
class ReportMetric {
  const ReportMetric({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;

  /// Pre-formatted. A metric can be money, a count or a name, and the card
  /// that shows it should not have to know which.
  final String value;

  final String? caption;
}

/// Everything one report render needs.
///
/// ## Every figure arrives computed
///
/// Totals, averages, shares, rankings — all produced by the repository,
/// which is standing in for the reporting API. Nothing here or above it
/// does arithmetic on money; `test/transactions/architecture_test.dart`
/// fails the build if that changes.
class ReportData {
  const ReportData({
    required this.income,
    required this.expenses,
    required this.net,
    required this.transactionCount,
    required this.categories,
    required this.points,
    required this.metrics,
    required this.isInProgress,
  });

  static const ReportData empty = ReportData(
    income: Money(0),
    expenses: Money(0),
    net: Money(0),
    transactionCount: 0,
    categories: [],
    points: [],
    metrics: [],
    isInProgress: false,
  );

  final Money income;

  /// A positive magnitude, matching the reporting contract.
  final Money expenses;

  /// Income minus expenses. A movement, never a balance: the app has no
  /// account connection and cannot know what anyone holds.
  final Money net;

  final int transactionCount;

  /// Spending by category, largest first.
  final List<CategorySlice> categories;

  /// The trend buckets. Empty when the window is too short to have a
  /// trend — a single day is a figure, not a shape.
  final List<ReportPoint> points;

  /// The secondary figures, already chosen and worded for this window.
  final List<ReportMetric> metrics;

  /// True when the window has not finished, so the totals are partial and
  /// the screen should say so rather than inviting a false comparison.
  final bool isInProgress;

  bool get isEmpty => transactionCount == 0;
}

/// One line of a year-over-year comparison.
class ComparisonLine {
  const ComparisonLine({
    required this.label,
    required this.earlier,
    required this.later,
    required this.delta,
    required this.percentChange,
    required this.higherIsBetter,
  });

  final String label;
  final Money earlier;
  final Money later;

  /// Later minus earlier. Signed.
  final Money delta;

  /// Null when the earlier figure is zero, where a percentage would be
  /// infinite — "up 100%" from nothing is not a fact, and printing it is
  /// how comparison screens mislead.
  final double? percentChange;

  /// Whether an increase is good news. Income up is good; spending up is
  /// not, and the two must not wear the same colour.
  final bool higherIsBetter;

  bool get hasIncreased => delta.minorUnits > 0;
  bool get isUnchanged => delta.minorUnits == 0;

  /// True when the movement is in the direction the user would want.
  bool get isFavourable =>
      isUnchanged || (hasIncreased == higherIsBetter);
}

/// Two years, side by side.
class YearComparison {
  const YearComparison({
    required this.earlierYear,
    required this.laterYear,
    required this.lines,
    required this.categories,
    required this.earlierIsComplete,
    required this.laterIsComplete,
  });

  final int earlierYear;
  final int laterYear;

  /// Income, expenses and net.
  final List<ComparisonLine> lines;

  /// Per-category movement, largest spender first.
  final List<ComparisonLine> categories;

  /// False when a year has no records at all, or is still running.
  ///
  /// Comparing a finished year with three months of another produces a
  /// true-looking number that means nothing, so the screen warns instead
  /// of quietly showing it.
  final bool earlierIsComplete;
  final bool laterIsComplete;

  bool get isTrustworthy => earlierIsComplete && laterIsComplete;

  bool get hasData => lines.isNotEmpty;
}
