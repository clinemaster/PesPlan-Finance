import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget_validator.dart';

import 'harness.dart';

void main() {
  group('amount', () {
    test('is required', () {
      expect(BudgetValidator.amount(null), 'Enter an amount');
    });

    test('must be positive', () {
      // Zero is a half-typed number far more often than it is a plan to
      // spend nothing — and the way to plan for no spending is not to
      // budget the category at all.
      expect(BudgetValidator.amount(0), 'Enter an amount greater than zero');
      expect(
        BudgetValidator.amount(-5000),
        'Enter an amount greater than zero',
      );
    });

    test('accepts a plausible figure', () {
      expect(BudgetValidator.amount(250000), isNull);
      expect(BudgetValidator.amount(1), isNull);
    });

    test('refuses a figure past the ceiling', () {
      expect(
        BudgetValidator.amount(BudgetValidator.maxMinorUnits + 1),
        contains('too large'),
      );
      expect(BudgetValidator.amount(BudgetValidator.maxMinorUnits), isNull);
    });
  });

  group('category', () {
    test('is required for a category budget', () {
      expect(
        BudgetValidator.category(BudgetKind.category, null),
        'Choose a category',
      );
      expect(
        BudgetValidator.category(BudgetKind.category, ''),
        'Choose a category',
      );
    });

    test('is accepted once chosen', () {
      expect(BudgetValidator.category(BudgetKind.category, 'food'), isNull);
    });

    test('is meaningless for an overall budget', () {
      expect(BudgetValidator.category(BudgetKind.overall, null), isNull);
    });
  });

  group('note', () {
    test('is optional', () {
      expect(BudgetValidator.description(null), isNull);
      expect(BudgetValidator.description('   '), isNull);
    });

    test('is capped', () {
      final tooLong = 'x' * (BudgetValidator.maxDescriptionLength + 1);

      expect(BudgetValidator.description(tooLong), contains('under'));
      expect(
        BudgetValidator.description('x' * BudgetValidator.maxDescriptionLength),
        isNull,
      );
    });
  });

  group('duplicates', () {
    final existing = [
      overallPlan(amount: 1400000),
      plan(
        amount: 250000,
        id: 'food',
        categoryId: 'food',
        categoryLabel: 'Food',
      ),
    ];

    test('a second overall budget for the month is refused', () {
      // Two overall budgets cannot both be the plan, and the arithmetic
      // underneath would have to pick one.
      expect(
        BudgetValidator.duplicate(
          kind: BudgetKind.overall,
          categoryId: null,
          existing: existing,
        ),
        contains('already has an overall budget'),
      );
    });

    test('a second budget for the same category is refused by name', () {
      expect(
        BudgetValidator.duplicate(
          kind: BudgetKind.category,
          categoryId: 'food',
          existing: existing,
        ),
        startsWith('Food already has a budget'),
      );
    });

    test('an untouched category is allowed', () {
      expect(
        BudgetValidator.duplicate(
          kind: BudgetKind.category,
          categoryId: 'transport',
          existing: existing,
        ),
        isNull,
      );
    });

    test('a budget does not duplicate itself while being edited', () {
      // Without this, opening Food and pressing Save would report Food as
      // a duplicate of Food.
      expect(
        BudgetValidator.duplicate(
          kind: BudgetKind.category,
          categoryId: 'food',
          existing: existing,
          editingId: 'food',
        ),
        isNull,
      );
      expect(
        BudgetValidator.duplicate(
          kind: BudgetKind.overall,
          categoryId: null,
          existing: existing,
          editingId: 'overall',
        ),
        isNull,
      );
    });
  });

  group('canSave', () {
    test('needs every rule satisfied', () {
      expect(
        BudgetValidator.canSave(
          kind: BudgetKind.category,
          minorUnits: 250000,
          categoryId: 'transport',
          description: 'Daily bajaji',
          existing: const <Budget>[],
        ),
        isTrue,
      );
    });

    test('refuses when any single rule fails', () {
      bool save({int? amount, String? category, String note = ''}) =>
          BudgetValidator.canSave(
            kind: BudgetKind.category,
            minorUnits: amount,
            categoryId: category,
            description: note,
            existing: [plan(amount: 1000, id: 'food')],
          );

      expect(save(amount: null, category: 'transport'), isFalse);
      expect(save(amount: 1000, category: null), isFalse);
      expect(save(amount: 1000, category: 'food'), isFalse, reason: 'dup');
      expect(
        save(amount: 1000, category: 'transport', note: 'x' * 200),
        isFalse,
      );
      expect(save(amount: 1000, category: 'transport'), isTrue);
    });
  });
}
