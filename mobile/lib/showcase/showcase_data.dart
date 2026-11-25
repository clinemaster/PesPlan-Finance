import '../core/design_system/design_system.dart';

/// Placeholder data for the showcase.
///
/// Fixed values, never random or date-dependent, so golden tests are stable
/// and a reviewer sees the same figures each time.
///
/// Amounts are in TZS, whole shillings (TZS has no subunit), at plausible
/// Tanzanian magnitudes — a design reviewed with `$12.50` would not reveal
/// that a real balance here is seven digits and needs the tabular figures and
/// the abbreviated axis ticks this system provides.
abstract final class ShowcaseData {
  const ShowcaseData._();

  static const Money balance = Money(2_450_000);
  static const Money income = Money(3_200_000);
  static const Money expenses = Money(-1_875_500);
  static const Money savings = Money(750_000);

  static const List<AppNavItem> navItems = [
    AppNavItem(icon: AppIcons.home, label: 'Home'),
    AppNavItem(icon: AppIcons.transactions, label: 'Activity', badgeCount: 3),
    AppNavItem(icon: AppIcons.budgets, label: 'Budgets'),
    AppNavItem(icon: AppIcons.insights, label: 'Insights'),
  ];

  /// A spread of categories, signs and name lengths — including one long
  /// enough to prove the row truncates rather than overflows.
  static const List<ShowcaseTransaction> transactions = [
    ShowcaseTransaction(
      description: 'Shoprite Mlimani City',
      category: 'groceries',
      amount: Money(-85_400),
      date: 'Today',
    ),
    ShowcaseTransaction(
      description: 'Salary — November',
      category: 'salary',
      amount: Money(3_200_000),
      date: 'Today',
    ),
    ShowcaseTransaction(
      description: 'Vodacom airtime bundle',
      category: 'airtime',
      amount: Money(-20_000),
      date: 'Yesterday',
    ),
    ShowcaseTransaction(
      description: 'Bajaji to Kariakoo market and back again',
      category: 'transport',
      amount: Money(-6_500),
      date: '23 Nov',
    ),
    ShowcaseTransaction(
      description: 'Luku electricity token',
      category: 'utilities',
      amount: Money(-45_000),
      date: '22 Nov',
    ),
  ];

  /// One of each budget state: comfortable, close to the limit, over.
  static const List<ShowcaseBudget> budgets = [
    ShowcaseBudget(
      category: 'groceries',
      spent: Money(420_000),
      limit: Money(600_000),
      ratio: 0.70,
      remaining: Money(180_000),
    ),
    ShowcaseBudget(
      category: 'transport',
      spent: Money(152_000),
      limit: Money(180_000),
      ratio: 0.84,
      remaining: Money(28_000),
    ),
    ShowcaseBudget(
      category: 'dining',
      spent: Money(230_000),
      limit: Money(150_000),
      ratio: 1.53,
      remaining: Money(80_000),
    ),
  ];

  /// Twelve months, with two deliberate gaps.
  ///
  /// August and December are `null`, not zero — the charts must render a break
  /// rather than a line dropping to the axis, and that only shows up if the
  /// placeholder data exercises it.
  static const List<ChartPoint> monthlySpend = [
    ChartPoint(label: 'Jan', value: 1_420_000),
    ChartPoint(label: 'Feb', value: 1_380_000),
    ChartPoint(label: 'Mar', value: 1_610_000),
    ChartPoint(label: 'Apr', value: 1_250_000),
    ChartPoint(label: 'May', value: 1_740_000),
    ChartPoint(label: 'Jun', value: 1_520_000),
    ChartPoint(label: 'Jul', value: 1_890_000),
    ChartPoint(label: 'Aug', value: null),
    ChartPoint(label: 'Sep', value: 1_460_000),
    ChartPoint(label: 'Oct', value: 1_705_000),
    ChartPoint(label: 'Nov', value: 1_875_500),
    ChartPoint(label: 'Dec', value: null),
  ];

  static const List<ChartPoint> monthlyIncome = [
    ChartPoint(label: 'Jan', value: 3_100_000),
    ChartPoint(label: 'Feb', value: 3_100_000),
    ChartPoint(label: 'Mar', value: 3_100_000),
    ChartPoint(label: 'Apr', value: 3_250_000),
    ChartPoint(label: 'May', value: 3_200_000),
    ChartPoint(label: 'Jun', value: 3_200_000),
    ChartPoint(label: 'Jul', value: 3_400_000),
    ChartPoint(label: 'Aug', value: null),
    ChartPoint(label: 'Sep', value: 3_200_000),
    ChartPoint(label: 'Oct', value: 3_200_000),
    ChartPoint(label: 'Nov', value: 3_200_000),
    ChartPoint(label: 'Dec', value: null),
  ];

  /// Six periods for the bar chart — a comfortable count on a phone.
  static const List<ChartPoint> weeklySpend = [
    ChartPoint(label: 'W1', value: 410_000),
    ChartPoint(label: 'W2', value: 528_000),
    ChartPoint(label: 'W3', value: 372_000),
    ChartPoint(label: 'W4', value: 565_500),
    ChartPoint(label: 'W5', value: 298_000),
    ChartPoint(label: 'W6', value: 455_000),
  ];
}

/// Placeholder transaction. A view model, not a domain entity — Phase 02 adds
/// no data layer.
class ShowcaseTransaction {
  const ShowcaseTransaction({
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
  });

  final String description;
  final String category;
  final Money amount;
  final String date;
}

/// Placeholder budget, with its ratio supplied rather than computed — the same
/// contract a real backend response will have.
class ShowcaseBudget {
  const ShowcaseBudget({
    required this.category,
    required this.spent,
    required this.limit,
    required this.ratio,
    required this.remaining,
  });

  final String category;
  final Money spent;
  final Money limit;
  final double ratio;
  final Money remaining;
}
