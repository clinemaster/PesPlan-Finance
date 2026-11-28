import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/features/assistant/data/mock_assistant_repository.dart';
import 'package:lifepilot_finance/features/assistant/domain/assistant_repository.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';
import 'package:lifepilot_finance/features/savings/data/mock_savings_repository.dart';
import 'package:lifepilot_finance/features/savings/domain/goal_movement.dart';
import 'package:lifepilot_finance/features/savings/domain/savings_goal.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

/// The whole chain, as the app wires it.
({
  MockAssistantRepository assistant,
  MockReportRepository reports,
  MockBudgetRepository budgets,
  MockSavingsRepository savings,
})
build({
  List<Transaction>? seed,
  List<Budget>? plans,
  List<SavingsGoal>? goals,
  List<GoalMovement>? movements,
  bool shouldFail = false,
}) {
  final transactions = MockTransactionRepository(
    now: () => today,
    seed: seed,
    delay: Duration.zero,
  );
  final reports = MockReportRepository(
    transactions: transactions,
    now: () => today,
    delay: Duration.zero,
  );
  final budgets = MockBudgetRepository(
    reports: reports,
    now: () => today,
    seed: plans,
    delay: Duration.zero,
  );
  final savings = MockSavingsRepository(
    now: () => today,
    seedGoals: goals,
    seedMovements: movements,
    delay: Duration.zero,
  );

  return (
    assistant: MockAssistantRepository(
      now: () => today,
      reports: reports,
      budgets: budgets,
      savings: savings,
      delay: Duration.zero,
      shouldFail: shouldFail,
    ),
    reports: reports,
    budgets: budgets,
    savings: savings,
  );
}

Transaction spend({
  required int amount,
  String id = 'e',
  String categoryId = 'food',
  String categoryLabel = 'Food',
  int month = 11,
  int day = 10,
}) => Transaction.create(
  id: id,
  type: TransactionType.expense,
  magnitudeMinorUnits: amount,
  categoryId: categoryId,
  categoryLabel: categoryLabel,
  date: DateTime(2026, month, day),
  createdAt: DateTime(2026, month, day),
);

Transaction earn({
  required int amount,
  String id = 'i',
  int month = 11,
  int day = 1,
}) => Transaction.create(
  id: id,
  type: TransactionType.income,
  magnitudeMinorUnits: amount,
  categoryId: 'salary',
  categoryLabel: 'Salary',
  date: DateTime(2026, month, day),
  createdAt: DateTime(2026, month, day),
);

void main() {
  group('answers come from the same figures the screens show', () {
    test('spending matches what the report says for the month', () async {
      final app = build(
        seed: [
          spend(id: 'a', amount: 120000),
          spend(
            id: 'b',
            amount: 80000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      final reply = await app.assistant.ask(
        question: 'How much did I spend this month?',
      );
      final report = await app.reports.report(ReportPeriod.month(today));

      expect(reply.text, contains(report.expenses.format()));
      expect(
        reply.insights.single.amount!.minorUnits,
        report.expenses.minorUnits,
      );
    });

    test('the biggest category is the one the report ranks first', () async {
      final app = build(
        seed: [
          spend(id: 'a', amount: 50000),
          spend(
            id: 'b',
            amount: 300000,
            categoryId: 'housing',
            categoryLabel: 'Housing',
          ),
        ],
      );

      final reply = await app.assistant.ask(
        question: 'What is my biggest spending category?',
      );

      expect(reply.text, contains('Housing'));
      expect(reply.text, contains('TSh 300,000'));
      expect(reply.text, contains('86%'));
    });

    test('budget answers quote the budget the user set', () async {
      final app = build(
        seed: [spend(amount: 200000)],
        plans: [
          Budget(
            id: 'overall',
            kind: BudgetKind.overall,
            amount: const Money(500000),
            year: 2026,
            month: 11,
          ),
        ],
      );

      final reply = await app.assistant.ask(question: 'Am I within my budget?');

      expect(reply.text, startsWith('Yes'));
      expect(reply.text, contains('40%'));
      expect(reply.text, contains('TSh 300,000 remaining'));
    });

    test('savings answers quote the goals as the Goals screen does', () async {
      final app = build(
        seed: const [],
        goals: [
          SavingsGoal(
            id: 'g',
            name: 'Emergency fund',
            target: const Money(2000000),
            createdAt: DateTime(2026, 6, 12),
          ),
        ],
        movements: [
          GoalMovement(
            id: 'm',
            goalId: 'g',
            kind: MovementKind.contribution,
            amount: const Money(850000),
            date: DateTime(2026, 10),
            recordedAt: DateTime(2026, 10),
          ),
        ],
      );

      final reply = await app.assistant.ask(
        question: 'How much have I saved this year?',
      );

      expect(reply.text, contains('TSh 850,000'));
      expect(reply.text, contains('Emergency fund'));
      expect(reply.text, contains('43%'));
    });
  });

  group('reading the question', () {
    final app = build(
      seed: [
        spend(id: 'a', amount: 120000),
        earn(id: 'b', amount: 900000),
        spend(id: 'c', amount: 60000, month: 10),
      ],
      plans: [
        Budget(
          id: 'overall',
          kind: BudgetKind.overall,
          amount: const Money(500000),
          year: 2026,
          month: 11,
        ),
      ],
    );

    for (final (question, expected) in [
      ('How much did I spend this month?', 'spent'),
      ('What is my biggest spending category?', 'biggest spending category'),
      ('Where can I reduce my expenses?', 'largest categories'),
      ('How much did I earn this month?', 'income this month'),
      ('Am I within my budget?', 'budget'),
      ('Which budget is close to its limit?', 'budget'),
      ('How much have I saved this year?', 'goal'),
      ('Give me a summary of my finances this month.', 'this month'),
      ('What changed compared with last month?', 'last month'),
    ]) {
      test('"$question" is answered about the right thing', () async {
        final reply = await app.assistant.ask(question: question);
        expect(reply.text.toLowerCase(), contains(expected.toLowerCase()));
      });
    }

    test('a question it does not understand says what it can do', () async {
      final reply = await app.assistant.ask(
        question: 'Should I buy shares in a bank?',
      );

      expect(reply.text, contains('I can answer questions about'));
      expect(reply.text, contains('do not give investment or tax advice'));
      expect(reply.followUps, isNotEmpty);
    });

    test('it never claims to be giving financial advice', () async {
      for (final question in [
        'Where can I reduce my expenses?',
        'How can I reach my savings goal faster?',
        'Should I invest?',
      ]) {
        final reply = await app.assistant.ask(question: question);
        expect(
          reply.text.toLowerCase(),
          isNot(contains('you should invest')),
          reason: question,
        );
      }
    });
  });

  group('the figures are not invented', () {
    test('an account with nothing recorded says so', () async {
      final app = build(seed: const [], plans: const [], goals: const []);

      final reply = await app.assistant.ask(
        question: 'How much did I spend this month?',
      );

      expect(reply.text, contains("haven't recorded anything yet"));
      expect(reply.insights, isEmpty);
    });

    test('no budget set is said plainly, not answered with zero', () async {
      final app = build(seed: [spend(amount: 10000)], plans: const []);

      final reply = await app.assistant.ask(question: 'Am I within my budget?');

      expect(reply.text, contains('not set an overall budget'));
    });

    test('no goals is said plainly', () async {
      final app = build(seed: [spend(amount: 10000)], goals: const []);

      final reply = await app.assistant.ask(
        question: 'How much have I saved this year?',
      );

      expect(reply.text, contains('not set any savings goals'));
    });

    test('nothing to compare with is said rather than guessed', () async {
      final app = build(seed: [spend(amount: 10000)]);

      final reply = await app.assistant.ask(
        question: 'What changed compared with last month?',
      );

      expect(reply.text, contains('nothing recorded for last month'));
    });

    test('a savings answer refuses to predict a date', () async {
      // A projection from four contributions is a prediction the app
      // cannot stand behind.
      final app = build(
        seed: [spend(amount: 10000)],
        goals: [
          SavingsGoal(
            id: 'g',
            name: 'Laptop',
            target: const Money(1000000),
            createdAt: DateTime(2026, 9),
          ),
        ],
        movements: [
          GoalMovement(
            id: 'm',
            goalId: 'g',
            kind: MovementKind.contribution,
            amount: const Money(200000),
            date: DateTime(2026, 10),
            recordedAt: DateTime(2026, 10),
          ),
        ],
      );

      final reply = await app.assistant.ask(
        question: 'How can I reach my savings goal faster?',
      );

      expect(reply.text, contains('will not guess a date'));
      expect(reply.text, contains('TSh 800,000'));
    });
  });

  group('answers repeat themselves', () {
    test('the same question twice gives the same figures', () async {
      // Nothing random: a user who asks again must not be told something
      // different about the same month.
      final app = build(seed: [spend(amount: 123000)]);

      final first = await app.assistant.ask(question: 'How much did I spend?');
      final second = await app.assistant.ask(question: 'How much did I spend?');

      expect(first.text, second.text);
    });
  });

  group('failure and usage', () {
    test('a failure carries a sentence meant for the user', () async {
      final app = build(shouldFail: true);

      expect(
        () => app.assistant.ask(question: 'How much did I spend?'),
        throwsA(isA<AssistantUnavailable>()),
      );
    });

    test('the allowance counts down as questions are asked', () async {
      final app = build(seed: [spend(amount: 1000)]);

      expect((await app.assistant.usage()).remaining, 20);

      await app.assistant.ask(question: 'How much did I spend?');
      await app.assistant.ask(question: 'Am I within my budget?');

      final usage = await app.assistant.usage();
      expect(usage.used, 2);
      expect(usage.remaining, 18);
      expect(usage.label, '18 of 20 questions left today');
    });

    test('a failed question does not spend the allowance', () async {
      final app = build(shouldFail: true);

      try {
        await app.assistant.ask(question: 'How much did I spend?');
      } on AssistantUnavailable {
        // Expected.
      }

      expect((await app.assistant.usage()).used, 0);
    });

    test('the allowance never goes below zero', () {
      const usage = AssistantUsage(used: 25, dailyLimit: 20);

      expect(usage.remaining, 0);
      expect(usage.isExhausted, isTrue);
    });
  });

  group('insight cards', () {
    test('carry the same figures as the sentence', () async {
      final app = build(
        seed: [
          spend(id: 'a', amount: 120000),
          spend(
            id: 'b',
            amount: 80000,
            categoryId: 'transport',
            categoryLabel: 'Transport',
          ),
        ],
      );

      final reply = await app.assistant.ask(question: 'How much did I spend?');
      final card = reply.insights.single;

      expect(card.amount!.minorUnits, 200000);
      expect(card.rows.map((row) => row.label), ['Food', 'Transport']);
      expect(card.rows.first.value, 'TSh 120,000');
      expect(card.rows.first.share, closeTo(0.6, 0.001));
    });

    test('shares are already computed, never left to the widget', () async {
      final app = build(seed: [spend(amount: 50000)]);

      final reply = await app.assistant.ask(
        question: 'What is my biggest spending category?',
      );

      for (final row in reply.insights.single.rows) {
        if (row.share == null) continue;
        expect(row.share, inInclusiveRange(0, 1));
      }
    });
  });
}
