import '../../../core/money/money.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_period.dart';
import '../domain/dashboard_repository.dart';

/// Whether the mock has anything to report.
///
/// The empty dashboard is a required state and is unreachable while the mock
/// always returns a populated account, so it is selectable. The Settings
/// screen exposes the switch; it goes away with the mock.
enum MockDataMode { populated, empty }

/// A stand-in for the reporting API.
///
/// ## Every figure here is a literal, including the derived ones
///
/// `net`, `remaining` and each `ratio` are written out rather than computed,
/// because this class stands where the Python reporting layer will stand,
/// and that layer is what computes them. Writing `income - expenses` here
/// would put the arithmetic back in Dart with extra steps, and the next
/// person would reasonably copy the pattern into a widget.
///
/// The consistency of those literals is pinned by tests, so a typo in the
/// mock cannot quietly ship a dashboard that does not add up.
///
/// Figures are whole Tanzanian shillings at plausible magnitudes — seven
/// digits, which is what makes the tabular figures and abbreviated axis
/// ticks in the design system earn their place.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    this.mode = MockDataMode.populated,
    this.delay = const Duration(milliseconds: 450),
  });

  MockDataMode mode;

  /// Long enough that the loading state is real and visible. Tests pass zero.
  final Duration delay;

  @override
  Future<DashboardData> load(DashboardPeriod period) async {
    await Future<void>.delayed(delay);

    if (mode == MockDataMode.empty) return const DashboardData.empty();

    return switch (period.kind) {
      PeriodKind.thisMonth => _thisMonth,
      PeriodKind.thisYear => _thisYear,
      PeriodKind.custom => _custom(period),
    };
  }

  // ------------------------------------------------------------ this month

  /// Four weeks. Income arrives once, on payday, so three weeks show no
  /// income bar — which is the real shape of a salaried month and worth
  /// seeing rather than smoothing away.
  static const DashboardData _thisMonth = DashboardData(
    income: Money(3_200_000),
    expenses: Money(1_875_500),
    net: Money(1_324_500),
    trend: TrendSeries(
      labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
      income: [3_200_000, 0, 0, 0],
      expenses: [520_000, 430_500, 495_000, 430_000],
    ),
    budget: BudgetOverview(
      limit: Money(2_200_000),
      spent: Money(1_875_500),
      remaining: Money(324_500),
      ratio: 0.85,
      status: BudgetStatus.closeToLimit,
      categoryCount: 6,
    ),
    savings: _savings,
    recentTransactions: _recent,
  );

  // ------------------------------------------------------------- this year

  /// Twelve months with two deliberate gaps. August and December are `null`,
  /// not zero: a month with no records must break the line rather than drop
  /// it to the axis, and that only gets exercised if the data contains it.
  static const DashboardData _thisYear = DashboardData(
    income: Money(31_950_000),
    expenses: Money(15_850_500),
    net: Money(16_099_500),
    trend: TrendSeries(
      labels: [
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
      ],
      income: [
        3_100_000,
        3_100_000,
        3_100_000,
        3_250_000,
        3_200_000,
        3_200_000,
        3_400_000,
        null,
        3_200_000,
        3_200_000,
        3_200_000,
        null,
      ],
      expenses: [
        1_420_000,
        1_380_000,
        1_610_000,
        1_250_000,
        1_740_000,
        1_520_000,
        1_890_000,
        null,
        1_460_000,
        1_705_000,
        1_875_500,
        null,
      ],
    ),
    budget: BudgetOverview(
      limit: Money(26_400_000),
      spent: Money(15_850_500),
      remaining: Money(10_549_500),
      ratio: 0.60,
      status: BudgetStatus.comfortable,
      categoryCount: 6,
    ),
    savings: _savings,
    recentTransactions: _recent,
  );

  // ---------------------------------------------------------------- custom

  /// A custom range reports the same account over a shorter window.
  ///
  /// The bucket labels come from the chosen dates so the chart describes the
  /// range the user actually picked, rather than showing generic buckets
  /// that could belong to any period.
  static DashboardData _custom(DashboardPeriod period) {
    final labels = _bucketLabels(period);

    return DashboardData(
      income: const Money(1_600_000),
      expenses: const Money(905_000),
      net: const Money(695_000),
      trend: TrendSeries(
        labels: labels,
        income: const [1_600_000, 0, 0, 0],
        expenses: const [268_000, 194_000, 231_000, 212_000],
      ),
      budget: const BudgetOverview(
        limit: Money(1_100_000),
        spent: Money(905_000),
        remaining: Money(195_000),
        ratio: 0.82,
        status: BudgetStatus.closeToLimit,
        categoryCount: 6,
      ),
      savings: _savings,
      recentTransactions: _recent,
    );
  }

  /// Four evenly spaced bucket labels across the range.
  ///
  /// Date arithmetic, not money arithmetic — Rule 1 is about amounts.
  static List<String> _bucketLabels(DashboardPeriod period) {
    final start = period.start;
    final end = period.end;
    if (start == null || end == null) {
      return const ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    }

    final span = end.difference(start).inDays;
    final step = (span / 4).ceil().clamp(1, 1000);

    return [
      for (var i = 0; i < 4; i++)
        _shortDate(start.add(Duration(days: step * i))),
    ];
  }

  static const List<String> _months = [
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

  static String _shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  // --------------------------------------------------------- shared pieces

  /// Savings is a running total, so it does not change with the period.
  ///
  /// Three goals, two previewed. The third ("Safari trip") has nothing saved
  /// yet, which is why the totals do not match the two shown — a real
  /// account looks like this, and a preview that always adds up to the
  /// headline hides the fact that it is a preview.
  static const SavingsOverview _savings = SavingsOverview(
    activeGoals: 3,
    totalSaved: Money(750_000),
    totalTarget: Money(3_200_000),
    ratio: 0.23,
    previews: [
      GoalPreview(
        name: 'Emergency fund',
        saved: Money(450_000),
        target: Money(1_000_000),
        ratio: 0.45,
        caption: 'Started in June',
      ),
      GoalPreview(
        name: 'New laptop',
        saved: Money(300_000),
        target: Money(1_500_000),
        ratio: 0.20,
        caption: 'Target: March 2027',
      ),
    ],
  );

  /// Five rows: a spread of categories and signs, one income so both
  /// indicators appear, and one description long enough to prove the row
  /// truncates rather than overflows.
  static const List<TransactionSummary> _recent = [
    TransactionSummary(
      id: 'txn-001',
      description: 'Shoprite Mlimani City',
      category: 'groceries',
      amount: Money(-85_400),
      date: 'Today',
    ),
    TransactionSummary(
      id: 'txn-002',
      description: 'Salary — November',
      category: 'business',
      amount: Money(3_200_000),
      date: 'Today',
    ),
    TransactionSummary(
      id: 'txn-003',
      description: 'Vodacom airtime bundle',
      category: 'airtime',
      amount: Money(-20_000),
      date: 'Yesterday',
    ),
    TransactionSummary(
      id: 'txn-004',
      description: 'Bajaji to Kariakoo market and back again',
      category: 'transport',
      amount: Money(-6_500),
      date: '23 Nov',
    ),
    TransactionSummary(
      id: 'txn-005',
      description: 'Luku electricity token',
      category: 'utilities',
      amount: Money(-45_000),
      date: '22 Nov',
    ),
  ];
}
