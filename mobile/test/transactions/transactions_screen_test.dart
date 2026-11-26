import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_filter.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';

import 'harness.dart';

void main() {
  group('the list', () {
    testWidgets('groups transactions under date headings', (tester) async {
      await TransactionsHarness.pump(tester);

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.byType(TransactionTile), findsWidgets);
    });

    testWidgets('shows description, category and date on a row', (
      tester,
    ) async {
      await TransactionsHarness.pump(tester);

      expect(find.text('Lunch at Chef Amin'), findsOneWidget);
      // Category and date share the row's second line, and the category
      // is shown by its label rather than its lowercase id.
      expect(find.textContaining('Food · Today'), findsWidgets);
    });

    testWidgets('distinguishes income from expense by sign', (tester) async {
      await TransactionsHarness.pump(tester);

      // The salary is yesterday's, and signed positive; the lunch today is
      // signed negative. The sign is the indicator, so it must be present.
      expect(find.text('+TSh 1,500,000'), findsOneWidget);
      expect(find.text('-TSh 12,000'), findsOneWidget);
    });

    testWidgets('summarises in, out and net for what is listed', (
      tester,
    ) async {
      await TransactionsHarness.pump(tester);

      expect(find.text('In'), findsOneWidget);
      expect(find.text('Out'), findsOneWidget);
      expect(find.text('Net'), findsOneWidget);
      expect(find.textContaining('transactions'), findsWidgets);
    });

    testWidgets('renders on a small phone without overflowing', (
      tester,
    ) async {
      await TransactionsHarness.pump(
        tester,
        size: TransactionsHarness.smallPhone,
      );
      await TransactionsHarness.scrollTo(tester, find.text('Yesterday'));

      expect(tester.takeException(), isNull);
    });
  });

  group('empty account', () {
    testWidgets('invites a first transaction rather than showing zeroes', (
      tester,
    ) async {
      await TransactionsHarness.pumpEmpty(tester);

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Add your first one'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNothing);
    });
  });

  group('search', () {
    testWidgets('narrows the list to matches', (tester) async {
      await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'lunch');

      expect(find.text('Lunch at Chef Amin'), findsOneWidget);
      expect(find.text('Monthly salary'), findsNothing);
    });

    testWidgets('matches on category as well as description', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'transport');

      // Asserted against the result set rather than a row count: the
      // history runs to three years, so how many transport rows exist is
      // not a fact this test should depend on.
      final view = await harness.container.read(
        transactionListProvider.future,
      );
      final matches = view.groups.expand((g) => g.transactions);

      expect(matches, isNotEmpty);
      expect(
        matches.every((t) => t.categoryId == 'transport'),
        isTrue,
        reason: 'a category search must not pull in other categories',
      );
      expect(find.text('Bajaji to the office'), findsOneWidget);
    });

    testWidgets('says so when nothing matches, without claiming the account '
        'is empty', (tester) async {
      await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'helicopter');

      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.text('No transactions yet'), findsNothing);
      expect(find.text('Clear search'), findsOneWidget);
    });

    testWidgets('clearing the search brings everything back', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'helicopter');
      expect(find.text('Nothing matches'), findsOneWidget);

      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(
        harness.container.read(transactionFilterProvider).query,
        isEmpty,
      );
    });

    testWidgets('the summary follows the search', (tester) async {
      // Narrowing to one transaction should report that transaction, not
      // the whole history.
      final harness = await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'lunch');

      final view = await harness.container.read(
        transactionListProvider.future,
      );
      expect(view.totals.count, 1);
      expect(find.textContaining('not your whole history'), findsOneWidget);
    });
  });

  group('type chips', () {
    testWidgets('Income narrows to income only', (tester) async {
      final harness = await TransactionsHarness.pump(tester);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly salary'), findsOneWidget);
      expect(find.text('Lunch at Chef Amin'), findsNothing);
      expect(
        harness.container.read(transactionFilterProvider).type?.name,
        'income',
      );
    });

    testWidgets('tapping the active chip again clears it', (tester) async {
      final harness = await TransactionsHarness.pump(tester);

      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(harness.container.read(transactionFilterProvider).type, isNull);
      expect(find.text('Monthly salary'), findsOneWidget);
    });

    testWidgets('an applied filter announces itself and can be cleared', (
      tester,
    ) async {
      final harness = await TransactionsHarness.pump(tester);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('1 filter applied'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(transactionFilterProvider).hasFilters,
        isFalse,
      );
    });
  });

  group('the filter sheet', () {
    testWidgets('filters by category', (tester) async {
      final harness = await TransactionsHarness.pump(tester);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(transactionFilterProvider).categoryIds,
        {'transport'},
      );
      expect(find.text('Bajaji to the office'), findsOneWidget);
      expect(find.text('Lunch at Chef Amin'), findsNothing);
    });

    testWidgets('clear all filters empties the facets but keeps the search', (
      tester,
    ) async {
      final harness = await TransactionsHarness.pump(tester);
      await TransactionsHarness.search(tester, 'bajaji');

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      // The screen behind the sheet has an Income chip too.
      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all filters'));
      await tester.pumpAndSettle();

      final filter = harness.container.read(transactionFilterProvider);
      expect(filter.hasFilters, isFalse);
      expect(
        filter.query,
        'bajaji',
        reason: 'clearing filters is not clearing a search',
      );
    });
  });

  group('filter model', () {
    test('counts only the facets, not the search box', () {
      const filter = TransactionFilter(query: 'lunch');
      expect(filter.activeCount, 0);
      expect(filter.hasQuery, isTrue);
      expect(filter.hasFilters, isFalse);
    });

    test('cleared() keeps the query', () {
      final filter = const TransactionFilter(
        query: 'lunch',
        categoryIds: {'food'},
      ).cleared();

      expect(filter.query, 'lunch');
      expect(filter.categoryIds, isEmpty);
    });
  });
}
