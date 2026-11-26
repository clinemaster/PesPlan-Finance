import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_category.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_filter.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

MockTransactionRepository makeRepository({List<Transaction>? seed}) =>
    MockTransactionRepository(
      now: () => today,
      seed: seed,
      delay: Duration.zero,
    );

Transaction make({
  required String id,
  required TransactionType type,
  required int magnitude,
  String categoryId = 'food',
  String categoryLabel = 'Food',
  String description = '',
  int daysAgo = 0,
}) {
  final date = DateTime(2026, 11, 26).subtract(Duration(days: daysAgo));
  return Transaction.create(
    id: id,
    type: type,
    magnitudeMinorUnits: magnitude,
    categoryId: categoryId,
    categoryLabel: categoryLabel,
    description: description,
    date: date,
    createdAt: date,
  );
}

void main() {
  group('the model keeps the sign honest', () {
    test('an expense is stored negative, income positive', () {
      expect(
        make(id: 'a', type: TransactionType.expense, magnitude: 5000)
            .amount
            .minorUnits,
        -5000,
      );
      expect(
        make(id: 'b', type: TransactionType.income, magnitude: 5000)
            .amount
            .minorUnits,
        5000,
      );
    });

    test('a magnitude is taken as a magnitude even if handed a negative', () {
      // The amount field cannot produce a negative, but the factory should
      // not depend on that to stay correct.
      expect(
        make(id: 'c', type: TransactionType.income, magnitude: -900).amount
            .minorUnits,
        900,
      );
    });

    test('an empty description falls back to the category for the title', () {
      final row = make(id: 'd', type: TransactionType.expense, magnitude: 1);
      expect(row.title, 'Food');
      expect(row.copyWith(description: 'Lunch').title, 'Lunch');
    });
  });

  group('totals', () {
    test('sum each side and net them', () async {
      final repository = makeRepository(
        seed: [
          make(id: '1', type: TransactionType.income, magnitude: 1000000),
          make(id: '2', type: TransactionType.expense, magnitude: 250000),
          make(id: '3', type: TransactionType.expense, magnitude: 150000),
        ],
      );

      final totals = (await repository.list(TransactionFilter.none)).totals;

      expect(totals.income.minorUnits, 1000000);
      // Reported as a positive magnitude, matching the reporting contract.
      expect(totals.expenses.minorUnits, 400000);
      expect(totals.net.minorUnits, 600000);
      expect(totals.count, 3);
    });

    test('describe the filtered set, not the whole history', () async {
      // The reason to filter at all: narrowing to Food should answer what
      // Food cost, not keep reporting the full total.
      final repository = makeRepository(
        seed: [
          make(
            id: '1',
            type: TransactionType.expense,
            magnitude: 10000,
            categoryId: 'food',
          ),
          make(
            id: '2',
            type: TransactionType.expense,
            magnitude: 90000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      final view = await repository.list(
        const TransactionFilter(categoryIds: {'food'}),
      );

      expect(view.totals.expenses.minorUnits, 10000);
      expect(view.matchCount, 1);
      expect(view.totalCount, 2, reason: 'the other one still exists');
    });

    test('an empty account totals zero without crashing', () async {
      final view = await makeRepository(seed: []).list(TransactionFilter.none);

      expect(view.totals.count, 0);
      expect(view.totals.net.minorUnits, 0);
      expect(view.isAccountEmpty, isTrue);
    });
  });

  group('grouping', () {
    test('groups by day, newest first, with relative headings', () async {
      final repository = makeRepository(
        seed: [
          make(id: '1', type: TransactionType.expense, magnitude: 1),
          make(id: '2', type: TransactionType.expense, magnitude: 2),
          make(id: '3', type: TransactionType.expense, magnitude: 3, daysAgo: 1),
          make(id: '4', type: TransactionType.expense, magnitude: 4, daysAgo: 5),
        ],
      );

      final groups = (await repository.list(TransactionFilter.none)).groups;

      expect(groups, hasLength(3));
      expect(groups[0].label, 'Today');
      expect(groups[0].transactions, hasLength(2));
      expect(groups[1].label, 'Yesterday');
      expect(groups[2].label, '21 November');
    });

    test('ordering is stable across repeated reads', () async {
      // Two transactions on the same day must not swap places between
      // builds, which is what a sort with no tiebreaker would allow.
      final repository = makeRepository();

      final first = (await repository.list(TransactionFilter.none)).groups
          .expand((g) => g.transactions)
          .map((t) => t.id)
          .toList();
      final second = (await repository.list(TransactionFilter.none)).groups
          .expand((g) => g.transactions)
          .map((t) => t.id)
          .toList();

      expect(first, second);
    });
  });

  group('search', () {
    late MockTransactionRepository repository;

    setUp(() {
      repository = makeRepository(
        seed: [
          make(
            id: '1',
            type: TransactionType.expense,
            magnitude: 12000,
            description: 'Lunch at Chef Amin',
          ),
          make(
            id: '2',
            type: TransactionType.expense,
            magnitude: 8000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
            description: 'Bajaji to the office',
          ),
          make(
            id: '3',
            type: TransactionType.income,
            magnitude: 1500000,
            categoryId: 'salary',
            categoryLabel: 'Salary',
            description: 'Monthly salary',
          ),
        ],
      );
    });

    Future<List<String>> idsFor(String query) async {
      final view = await repository.list(TransactionFilter(query: query));
      return view.groups.expand((g) => g.transactions).map((t) => t.id).toList();
    }

    test('matches the description', () async {
      expect(await idsFor('lunch'), ['1']);
    });

    test('matches the category label', () async {
      expect(await idsFor('transport'), ['2']);
    });

    test('is case-insensitive', () async {
      expect(await idsFor('LUNCH'), ['1']);
    });

    test('every word must match, so more words narrow', () async {
      expect(await idsFor('lunch chef'), ['1']);
      expect(await idsFor('lunch bajaji'), isEmpty);
    });

    test('a query matching nothing returns no results but keeps the count',
        () async {
      final view = await repository.list(
        const TransactionFilter(query: 'helicopter'),
      );

      expect(view.hasResults, isFalse);
      expect(view.isAccountEmpty, isFalse, reason: 'the account is not empty');
      expect(view.totalCount, 3);
    });

    test('an empty query matches everything', () async {
      expect(await idsFor('   '), hasLength(3));
    });
  });

  group('filters', () {
    late MockTransactionRepository repository;

    setUp(() {
      repository = makeRepository(
        seed: [
          make(id: 'food-today', type: TransactionType.expense, magnitude: 1),
          make(
            id: 'transport-old',
            type: TransactionType.expense,
            magnitude: 2,
            categoryId: 'transport',
            categoryLabel: 'Transport',
            daysAgo: 10,
          ),
          make(
            id: 'salary',
            type: TransactionType.income,
            magnitude: 3,
            categoryId: 'salary',
            categoryLabel: 'Salary',
            daysAgo: 3,
          ),
        ],
      );
    });

    Future<List<String>> idsFor(TransactionFilter filter) async {
      final view = await repository.list(filter);
      return view.groups.expand((g) => g.transactions).map((t) => t.id).toList();
    }

    test('by type', () async {
      expect(
        await idsFor(const TransactionFilter(type: TransactionType.income)),
        ['salary'],
      );
      expect(
        await idsFor(const TransactionFilter(type: TransactionType.expense)),
        containsAll(<String>['food-today', 'transport-old']),
      );
    });

    test('by category', () async {
      expect(
        await idsFor(const TransactionFilter(categoryIds: {'transport'})),
        ['transport-old'],
      );
    });

    test('by several categories at once', () async {
      expect(
        await idsFor(
          const TransactionFilter(categoryIds: {'transport', 'salary'}),
        ),
        hasLength(2),
      );
    });

    test('by date range, inclusive at both ends', () async {
      // A transaction recorded at 18:00 must not fall outside a range
      // ending on its own date.
      expect(
        await idsFor(
          TransactionFilter(
            from: DateTime(2026, 11, 23),
            to: DateTime(2026, 11, 23),
          ),
        ),
        ['salary'],
      );
    });

    test('with an open-ended range', () async {
      expect(
        await idsFor(TransactionFilter(from: DateTime(2026, 11, 24))),
        ['food-today'],
      );
    });

    test('combined, they narrow rather than widen', () async {
      expect(
        await idsFor(
          const TransactionFilter(
            type: TransactionType.expense,
            categoryIds: {'salary'},
          ),
        ),
        isEmpty,
      );
    });
  });

  group('writes', () {
    test('add makes the transaction findable and moves the totals', () async {
      final repository = makeRepository(seed: []);

      await repository.add(
        make(id: 'new', type: TransactionType.expense, magnitude: 7500),
      );

      final view = await repository.list(TransactionFilter.none);
      expect(view.matchCount, 1);
      expect(view.totals.expenses.minorUnits, 7500);
      expect(await repository.byId('new'), isNotNull);
    });

    test('update replaces in place and keeps the id', () async {
      final repository = makeRepository(
        seed: [make(id: 'x', type: TransactionType.expense, magnitude: 1000)],
      );

      await repository.update(
        make(id: 'x', type: TransactionType.income, magnitude: 4000),
      );

      final view = await repository.list(TransactionFilter.none);
      expect(view.matchCount, 1, reason: 'edited, not duplicated');
      expect(view.totals.income.minorUnits, 4000);
      expect(view.totals.expenses.minorUnits, 0);
    });

    test('update of something gone fails loudly', () async {
      final repository = makeRepository(seed: []);

      expect(
        () => repository.update(
          make(id: 'ghost', type: TransactionType.expense, magnitude: 1),
        ),
        throwsStateError,
      );
    });

    test('delete removes it and the totals follow', () async {
      final repository = makeRepository(
        seed: [
          make(id: 'a', type: TransactionType.expense, magnitude: 1000),
          make(id: 'b', type: TransactionType.expense, magnitude: 2000),
        ],
      );

      await repository.delete('a');

      final view = await repository.list(TransactionFilter.none);
      expect(view.matchCount, 1);
      expect(view.totals.expenses.minorUnits, 2000);
      expect(await repository.byId('a'), isNull);
    });

    test('deleting the last one leaves an empty account, not a broken one',
        () async {
      final repository = makeRepository(
        seed: [make(id: 'only', type: TransactionType.expense, magnitude: 5)],
      );

      await repository.delete('only');

      expect(
        (await repository.list(TransactionFilter.none)).isAccountEmpty,
        isTrue,
      );
    });

    test('minted ids are unique', () {
      final repository = makeRepository();
      final ids = {for (var i = 0; i < 50; i++) repository.newId()};

      expect(ids, hasLength(50));
    });
  });

  group('the seed', () {
    test('exercises today, yesterday and both signs', () async {
      final view = await makeRepository().list(TransactionFilter.none);

      expect(view.groups.first.label, 'Today');
      expect(view.groups[1].label, 'Yesterday');
      expect(view.totals.income.minorUnits, greaterThan(0));
      expect(view.totals.expenses.minorUnits, greaterThan(0));
    });

    test('every seeded category exists in the catalogue', () async {
      // A seed row filed under a category the picker does not offer would
      // be uneditable: opening it would clear the category silently.
      final view = await makeRepository().list(TransactionFilter.none);

      for (final transaction in view.groups.expand((g) => g.transactions)) {
        expect(
          TransactionCategories.forType(
            transaction.type,
          ).map((c) => c.id),
          contains(transaction.categoryId),
          reason: '${transaction.id} uses an unknown category',
        );
      }
    });
  });
}
