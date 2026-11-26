import 'dart:math' as math;

import '../domain/date_labels.dart';
import '../domain/transaction.dart';

/// Three years of plausible activity, generated the same way every time.
///
/// ## Why generated rather than written out
///
/// Reports need years of history to have anything to report on — a
/// year-over-year comparison needs two years, a "highest spending month"
/// needs twelve. Three hundred-odd hand-written rows would be unreadable
/// and would rot the moment a category changed.
///
/// ## Why it is still deterministic
///
/// The generator is seeded with a fixed constant, so the same clock always
/// produces the same history. Figures do not drift between rebuilds, a
/// reviewer sees the same report twice, and a test can assert on an exact
/// total. That is the property that matters — not the absence of a random
/// number generator.
///
/// Amounts drift upward year on year and spending is seasonal, so the
/// comparison screens have something true to show rather than two flat
/// lines.
abstract final class TransactionHistory {
  const TransactionHistory._();

  /// How many complete months before the current one to generate.
  ///
  /// Thirty-five plus the current month is three years, which is the
  /// minimum that makes a year-over-year screen worth opening.
  static const int monthsOfHistory = 35;

  /// Fixed, so the history is stable across runs and machines.
  static const int _seed = 20261126;

  /// The current month is left to [recent] so the hand-written rows there
  /// stay the ones a reviewer sees first.
  static List<Transaction> generate({required DateTime now}) {
    final random = math.Random(_seed);
    final transactions = <Transaction>[...recent(now)];
    var sequence = 0;

    final thisMonth = DateTime(now.year, now.month);

    for (var monthsBack = 1; monthsBack <= monthsOfHistory; monthsBack++) {
      final month = DateTime(thisMonth.year, thisMonth.month - monthsBack);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      // Salaries rise a little each year, so a year-over-year comparison
      // has a real direction rather than noise around a flat line.
      final yearsBack = (monthsBack / 12).floor();
      final salary = 1500000 - yearsBack * 120000;

      Transaction add({
        required int day,
        required TransactionType type,
        required int magnitude,
        required String categoryId,
        required String categoryLabel,
        required String description,
      }) {
        sequence++;
        final date = DateTime(
          month.year,
          month.month,
          day.clamp(1, daysInMonth),
        );
        return Transaction.create(
          id: 'gen-$sequence',
          type: type,
          magnitudeMinorUnits: magnitude,
          categoryId: categoryId,
          categoryLabel: categoryLabel,
          description: description,
          date: date,
          createdAt: date.add(Duration(minutes: 540 + sequence % 300)),
        );
      }

      /// A figure that varies but never wildly, so no month looks broken.
      int near(int base) =>
          (base * (0.82 + random.nextDouble() * 0.36)).round() ~/ 100 * 100;

      transactions.add(
        add(
          day: 28,
          type: TransactionType.income,
          magnitude: salary,
          categoryId: 'salary',
          categoryLabel: 'Salary',
          description: 'Monthly salary',
        ),
      );

      // Side income, but not every month — an account where every month is
      // identical teaches a reviewer nothing about the comparison screens.
      if (monthsBack % 3 == 0) {
        transactions.add(
          add(
            day: 12 + random.nextInt(8),
            type: TransactionType.income,
            magnitude: near(280000),
            categoryId: 'freelance',
            categoryLabel: 'Freelance',
            description: 'Freelance project',
          ),
        );
      }
      if (monthsBack % 7 == 0) {
        transactions.add(
          add(
            day: 5 + random.nextInt(10),
            type: TransactionType.income,
            magnitude: near(140000),
            categoryId: 'business',
            categoryLabel: 'Business',
            description: 'Kiosk takings',
          ),
        );
      }

      for (final spend in _monthlySpending) {
        for (var i = 0; i < spend.perMonth; i++) {
          transactions.add(
            add(
              day: 2 + random.nextInt(daysInMonth - 2),
              type: TransactionType.expense,
              // December and January cost more, as they do everywhere.
              magnitude: near(
                month.month == 12 || month.month == 1
                    ? (spend.typical * 1.25).round()
                    : spend.typical,
              ),
              categoryId: spend.categoryId,
              categoryLabel: spend.categoryLabel,
              description: spend.description,
            ),
          );
        }
      }
    }

    return transactions;
  }

  /// The current month, written out by hand.
  ///
  /// These are the rows a reviewer sees on opening the app, so they are
  /// specific and readable rather than generated: real shop names, a long
  /// description to prove the row truncates, and both signs on screen at
  /// once.
  static List<Transaction> recent(DateTime now) {
    final today = DateLabels.dayOf(now);
    DateTime daysAgo(int days) => today.subtract(Duration(days: days));

    var sequence = 0;
    Transaction make({
      required int days,
      required TransactionType type,
      required int magnitude,
      required String categoryId,
      required String categoryLabel,
      required String description,
    }) {
      sequence++;
      final date = daysAgo(days);
      return Transaction.create(
        id: 'seed-$sequence',
        type: type,
        magnitudeMinorUnits: magnitude,
        categoryId: categoryId,
        categoryLabel: categoryLabel,
        description: description,
        date: date,
        // Spaced so same-day ordering is stable and deterministic.
        createdAt: date.add(Duration(minutes: 600 - sequence)),
      );
    }

    return [
      make(
        days: 0,
        type: TransactionType.expense,
        magnitude: 12000,
        categoryId: 'food',
        categoryLabel: 'Food',
        description: 'Lunch at Chef Amin',
      ),
      make(
        days: 0,
        type: TransactionType.expense,
        magnitude: 8000,
        categoryId: 'transport',
        categoryLabel: 'Transport',
        description: 'Bajaji to the office',
      ),
      make(
        days: 0,
        type: TransactionType.expense,
        magnitude: 85400,
        categoryId: 'food',
        categoryLabel: 'Food',
        description: 'Shoprite Mlimani City',
      ),
      make(
        days: 1,
        type: TransactionType.income,
        magnitude: 1500000,
        categoryId: 'salary',
        categoryLabel: 'Salary',
        description: 'Monthly salary',
      ),
      make(
        days: 1,
        type: TransactionType.expense,
        magnitude: 45000,
        categoryId: 'shopping',
        categoryLabel: 'Shopping',
        description: 'Groceries for the week',
      ),
      make(
        days: 2,
        type: TransactionType.expense,
        magnitude: 20000,
        categoryId: 'bills',
        categoryLabel: 'Bills',
        description: 'Vodacom airtime bundle',
      ),
      make(
        days: 2,
        type: TransactionType.expense,
        magnitude: 45000,
        categoryId: 'bills',
        categoryLabel: 'Bills',
        description: 'Luku electricity token',
      ),
      make(
        days: 3,
        type: TransactionType.expense,
        magnitude: 6500,
        categoryId: 'transport',
        categoryLabel: 'Transport',
        description: 'Bajaji to Kariakoo market and back again',
      ),
      make(
        days: 4,
        type: TransactionType.income,
        magnitude: 320000,
        categoryId: 'freelance',
        categoryLabel: 'Freelance',
        description: 'Website for Mama Lishe',
      ),
      make(
        days: 5,
        type: TransactionType.expense,
        magnitude: 150000,
        categoryId: 'health',
        categoryLabel: 'Health',
        description: 'Clinic visit',
      ),
      make(
        days: 6,
        type: TransactionType.expense,
        magnitude: 35000,
        categoryId: 'entertainment',
        categoryLabel: 'Entertainment',
        description: 'Cinema with friends',
      ),
      make(
        days: 8,
        type: TransactionType.expense,
        magnitude: 400000,
        categoryId: 'housing',
        categoryLabel: 'Housing',
        description: 'Rent contribution',
      ),
      make(
        days: 9,
        type: TransactionType.income,
        magnitude: 50000,
        categoryId: 'gift',
        categoryLabel: 'Gift',
        description: 'Birthday money from auntie',
      ),
      make(
        days: 11,
        type: TransactionType.expense,
        magnitude: 180000,
        categoryId: 'education',
        categoryLabel: 'Education',
        description: 'Short course fee',
      ),
      make(
        days: 12,
        type: TransactionType.expense,
        magnitude: 9500,
        categoryId: 'food',
        categoryLabel: 'Food',
        description: 'Chipsi mayai',
      ),
      make(
        days: 14,
        type: TransactionType.income,
        magnitude: 95000,
        categoryId: 'business',
        categoryLabel: 'Business',
        description: 'Kiosk takings',
      ),
    ];
  }
}

/// One recurring kind of spending, and roughly how much of it happens.
class _Spending {
  const _Spending({
    required this.categoryId,
    required this.categoryLabel,
    required this.description,
    required this.typical,
    required this.perMonth,
  });

  final String categoryId;
  final String categoryLabel;
  final String description;

  /// Typical magnitude in whole shillings.
  final int typical;

  /// How many of these a month sees.
  final int perMonth;
}

/// The shape of an ordinary month. Housing dominates, food is frequent,
/// and the long tail is small — which is what makes a category breakdown
/// worth looking at.
const List<_Spending> _monthlySpending = [
  _Spending(
    categoryId: 'housing',
    categoryLabel: 'Housing',
    description: 'Rent contribution',
    typical: 400000,
    perMonth: 1,
  ),
  _Spending(
    categoryId: 'food',
    categoryLabel: 'Food',
    description: 'Groceries and meals',
    typical: 62000,
    perMonth: 6,
  ),
  _Spending(
    categoryId: 'transport',
    categoryLabel: 'Transport',
    description: 'Daladala and bajaji',
    typical: 18000,
    perMonth: 4,
  ),
  _Spending(
    categoryId: 'bills',
    categoryLabel: 'Bills',
    description: 'Airtime and Luku',
    typical: 38000,
    perMonth: 2,
  ),
  _Spending(
    categoryId: 'shopping',
    categoryLabel: 'Shopping',
    description: 'Household shopping',
    typical: 70000,
    perMonth: 1,
  ),
  _Spending(
    categoryId: 'health',
    categoryLabel: 'Health',
    description: 'Pharmacy',
    typical: 45000,
    perMonth: 1,
  ),
  _Spending(
    categoryId: 'entertainment',
    categoryLabel: 'Entertainment',
    description: 'Going out',
    typical: 32000,
    perMonth: 1,
  ),
];
