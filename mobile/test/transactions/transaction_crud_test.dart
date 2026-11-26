import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_validator.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// The amount is the first TextField on the form; the description is the
/// last. The category is a grid of buttons and the date is a picker, so
/// neither is a TextField — which is what keeps these indices stable.
Finder get amountField => find.byType(TextField).first;
Finder get descriptionField => find.byType(TextField).last;

Future<void> openNewTransaction(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add transaction'));
  await tester.pumpAndSettle();
}

void main() {
  group('adding', () {
    testWidgets('an expense appears in the list immediately', (tester) async {
      final harness = await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.enterText(amountField, '25000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.enterText(descriptionField, 'Nyama choma');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Nyama choma'), findsOneWidget);
      expect(find.text('-TSh 25,000'), findsOneWidget);
      expect(harness.repository.all, hasLength(1));
      expect(harness.repository.all.single.amount.minorUnits, -25000);
    });

    testWidgets('income is stored positive and shown positive', (
      tester,
    ) async {
      final harness = await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.enterText(amountField, '900000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(harness.repository.all.single.amount.minorUnits, 900000);
      expect(find.text('+TSh 900,000'), findsOneWidget);
    });

    testWidgets('the form offers only the chosen side of the ledger', (
      tester,
    ) async {
      await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
    });

    testWidgets('switching type drops a category the new side lacks', (
      tester,
    ) async {
      // Keeping "Salary" selected after switching to Expense would file an
      // expense under a category its own type does not offer.
      final harness = await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();

      await tester.enterText(amountField, '1000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a category'), findsOneWidget);
      expect(harness.repository.all, isEmpty);
    });

    testWidgets('returns to the list after saving', (tester) async {
      await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.enterText(amountField, '1000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('New transaction'), findsNothing);
    });

    testWidgets('confirms the save', (tester) async {
      await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.enterText(amountField, '1000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction saved'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('an empty form explains what is missing rather than doing '
        'nothing', (tester) async {
      final harness = await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount'), findsOneWidget);
      expect(find.text('Choose a category'), findsOneWidget);
      expect(harness.repository.all, isEmpty);
    });

    testWidgets('zero is rejected', (tester) async {
      final harness = await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(harness.repository.all, isEmpty);
    });

    testWidgets('errors clear as soon as the field is fixed', (tester) async {
      await TransactionsHarness.pump(tester, seed: const []);
      await openNewTransaction(tester);

      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(amountField, '500');
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount'), findsNothing);
    });

    test('the validator rejects an absurd amount', () {
      expect(TransactionValidator.amount(null), isNotNull);
      expect(TransactionValidator.amount(0), isNotNull);
      expect(TransactionValidator.amount(-1), isNotNull);
      expect(TransactionValidator.amount(1), isNull);
      expect(
        TransactionValidator.amount(TransactionValidator.maxMinorUnits + 1),
        isNotNull,
      );
    });

    test('the validator refuses a future date', () {
      final today = DateTime(2026, 11, 26);

      expect(
        TransactionValidator.date(DateTime(2026, 11, 27), today: today),
        isNotNull,
      );
      expect(
        TransactionValidator.date(DateTime(2026, 11, 26, 23), today: today),
        isNull,
        reason: 'later today is still today',
      );
      expect(
        TransactionValidator.date(DateTime(2020, 1, 1), today: today),
        isNull,
      );
    });

    test('the validator bounds the description', () {
      expect(TransactionValidator.description(''), isNull);
      expect(TransactionValidator.description('a' * 120), isNull);
      expect(TransactionValidator.description('a' * 121), isNotNull);
    });
  });

  group('details', () {
    testWidgets('tapping a row opens everything recorded about it', (
      tester,
    ) async {
      await TransactionsHarness.pump(tester);

      await tester.tap(find.text('Lunch at Chef Amin'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Reference'), findsOneWidget);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('editing', () {
    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.text('Lunch at Chef Amin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('the form opens pre-filled', (tester) async {
      await TransactionsHarness.pump(tester);
      await openEditor(tester);

      expect(find.text('Edit transaction'), findsOneWidget);
      expect(find.text('Lunch at Chef Amin'), findsOneWidget);
      expect(find.text('12000'), findsOneWidget);
    });

    testWidgets('a changed amount shows in the list straight away', (
      tester,
    ) async {
      await TransactionsHarness.pump(tester);
      await openEditor(tester);

      await tester.enterText(amountField, '18500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('-TSh 18,500'), findsOneWidget);
      expect(find.text('-TSh 12,000'), findsNothing);
      expect(find.text('Transaction updated'), findsOneWidget);
    });

    testWidgets('editing replaces rather than duplicating', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      final before = harness.repository.all.length;

      await openEditor(tester);
      await tester.enterText(descriptionField, 'Lunch with Juma');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(harness.repository.all, hasLength(before));
      expect(find.text('Lunch with Juma'), findsOneWidget);
    });

    testWidgets('an expense can be corrected into income', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      await openEditor(tester);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gift'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final edited = harness.repository.all.firstWhere(
        (t) => t.description == 'Lunch at Chef Amin',
      );
      expect(edited.type, TransactionType.income);
      expect(edited.amount.minorUnits, 12000, reason: 'sign follows the type');
    });
  });

  group('deleting', () {
    Future<void> openDetail(WidgetTester tester) async {
      await tester.tap(find.text('Lunch at Chef Amin'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks before removing anything', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      final before = harness.repository.all.length;

      await openDetail(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this transaction?'), findsOneWidget);
      expect(
        find.textContaining('removed from your transaction history'),
        findsOneWidget,
      );
      expect(harness.repository.all, hasLength(before));
    });

    testWidgets('cancelling keeps the transaction', (tester) async {
      final harness = await TransactionsHarness.pump(tester);
      final before = harness.repository.all.length;

      await openDetail(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.repository.all, hasLength(before));
      expect(find.text('Lunch at Chef Amin'), findsWidgets);
    });

    testWidgets('confirming removes it from the list and the totals', (
      tester,
    ) async {
      final harness = await TransactionsHarness.pump(tester);
      final before = harness.repository.all.length;

      await openDetail(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // The dialog's own Delete, which sits above the sheet's.
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(harness.repository.all, hasLength(before - 1));
      expect(find.text('Lunch at Chef Amin'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
    });

    testWidgets('deleting the last one shows the empty account state', (
      tester,
    ) async {
      await TransactionsHarness.pump(
        tester,
        seed: [
          Transaction.create(
            id: 'only',
            type: TransactionType.expense,
            magnitudeMinorUnits: 5000,
            categoryId: 'food',
            categoryLabel: 'Food',
            description: 'The only one',
            date: TransactionsHarness.now,
            createdAt: TransactionsHarness.now,
          ),
        ],
      );

      await tester.tap(find.text('The only one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet'), findsOneWidget);
    });
  });
}
