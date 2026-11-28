import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/features/assistant/domain/suggested_question.dart';
import 'package:lifepilot_finance/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:lifepilot_finance/features/assistant/presentation/widgets/assistant_widgets.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

Transaction spend({
  required int amount,
  String id = 'e',
  String categoryId = 'food',
  String categoryLabel = 'Food',
  int day = 10,
}) => Transaction.create(
  id: id,
  type: TransactionType.expense,
  magnitudeMinorUnits: amount,
  categoryId: categoryId,
  categoryLabel: categoryLabel,
  date: DateTime(2026, 11, day),
  createdAt: DateTime(2026, 11, day),
);

Budget monthlyBudget(int amount) => Budget(
  id: 'overall',
  kind: BudgetKind.overall,
  amount: Money(amount),
  year: 2026,
  month: 11,
);

void main() {
  group('the welcome', () {
    testWidgets('introduces itself without overpromising', (tester) async {
      await AssistantHarness.pump(tester);

      expect(find.text("Hi! I'm your LifePilot assistant."), findsOneWidget);
      expect(find.textContaining('understand your spending'), findsOneWidget);

      // The note sits at the end of the suggestions, below the fold.
      await AssistantHarness.dragTo(
        tester,
        find.textContaining('general guidance, not financial advice'),
      );
      expect(
        find.textContaining('general guidance, not financial advice'),
        findsOneWidget,
      );
    });

    testWidgets('says where its answers come from', (tester) async {
      // The trust note, and in this phase it is literally true.
      await AssistantHarness.pump(tester);
      await AssistantHarness.dragTo(
        tester,
        find.textContaining('nothing leaves your phone'),
      );

      expect(find.textContaining('nothing leaves your phone'), findsOneWidget);
    });

    testWidgets('never offers the same question twice', (tester) async {
      // The quick picks are drawn from the groups below them, and a
      // chip that appears twice on one screen reads as a mistake.
      await AssistantHarness.pump(tester);

      for (final question in SuggestionGroup.opening) {
        await AssistantHarness.dragTo(tester, find.text(question));
        expect(find.text(question), findsOneWidget, reason: question);
      }
    });

    testWidgets('offers questions in every area', (tester) async {
      await AssistantHarness.pump(tester);

      expect(find.text('Try asking'), findsOneWidget);
      for (final group in ['Spending', 'Income', 'Budgets', 'Savings']) {
        await AssistantHarness.dragTo(tester, find.text(group));
        expect(find.text(group), findsWidgets, reason: group);
      }
    });
  });

  group('asking', () {
    testWidgets('a typed question gets an answer about the figures', (
      tester,
    ) async {
      await AssistantHarness.pump(
        tester,
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

      await AssistantHarness.ask(tester, 'How much did I spend this month?');

      expect(find.text('How much did I spend this month?'), findsOneWidget);
      expect(find.textContaining('TSh 200,000'), findsWidgets);
      expect(find.textContaining('Food was your biggest'), findsOneWidget);
    });

    testWidgets('a suggestion sends the question it shows', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 50000)]);

      await AssistantHarness.tapSuggestion(
        tester,
        'How much did I spend this month?',
      );

      expect(find.byType(ChatBubble), findsNWidgets(2));
    });

    testWidgets('the answer carries a card with the same figures', (
      tester,
    ) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 120000)]);
      await AssistantHarness.ask(tester, 'How much did I spend this month?');

      expect(find.byType(InsightCard), findsOneWidget);
      expect(find.text('Spending this month'), findsOneWidget);
      expect(find.text('TSh 120,000'), findsWidgets);
    });

    testWidgets('the welcome gives way to the conversation', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);
      await AssistantHarness.ask(tester, 'How much did I spend?');

      expect(find.text("Hi! I'm your LifePilot assistant."), findsNothing);
      expect(find.text('Try asking'), findsNothing);
    });

    testWidgets('an empty question sends nothing', (tester) async {
      await AssistantHarness.pump(tester);

      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubble), findsNothing);
    });

    testWidgets('a budget question quotes the budget that was set', (
      tester,
    ) async {
      await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 200000)],
        budgetPlans: [monthlyBudget(500000)],
      );

      await AssistantHarness.ask(tester, 'Am I within my budget?');

      expect(find.textContaining('within your budget'), findsOneWidget);
      expect(find.textContaining('TSh 300,000 remaining'), findsOneWidget);
      expect(find.text('Monthly budget'), findsOneWidget);
    });

    testWidgets('an answer offers what to ask next', (tester) async {
      final harness = await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 50000)],
      );
      await AssistantHarness.ask(tester, 'How much did I spend this month?');

      await AssistantHarness.dragTo(
        tester,
        find.text('Am I within my budget?'),
      );
      await tester.tap(find.text('Am I within my budget?'));
      await tester.pumpAndSettle();

      // Counted in the thread rather than on screen: a ListView only
      // builds what is visible, and the first exchange has scrolled off.
      expect(harness.container.read(assistantProvider).messages, hasLength(4));
    });
  });

  group('while it is thinking', () {
    testWidgets('a typing indicator shows and then goes', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);

      await tester.enterText(
        find.byType(TextField).last,
        'How much did I spend?',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send'));
      // One frame: the question is in, the answer is not.
      await tester.pump();

      expect(find.byType(TypingIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(TypingIndicator), findsNothing);
    });

    testWidgets('the send button is disabled until the answer lands', (
      tester,
    ) async {
      // Two questions in flight would land in either order, and the
      // second would read as an answer to the first.
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);

      await tester.enterText(
        find.byType(TextField).last,
        'How much did I spend?',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      final send = tester.widget<AppIconButton>(
        find.ancestor(
          of: find.byTooltip('Send'),
          matching: find.byType(AppIconButton),
        ),
      );
      expect(send.onPressed, isNull);

      await tester.pumpAndSettle();
    });
  });

  group('when it fails', () {
    testWidgets('the question is marked and the reason is given', (
      tester,
    ) async {
      await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 1000)],
        shouldFail: true,
      );

      await AssistantHarness.ask(tester, 'How much did I spend?');

      expect(find.text('Not sent'), findsOneWidget);
      expect(find.textContaining("couldn't work that out"), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retrying asks the same question once more', (tester) async {
      // Once more, not twice over: the failed question is replaced
      // rather than left above its own retry.
      await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 1000)],
        shouldFail: true,
      );
      await AssistantHarness.ask(tester, 'How much did I spend?');

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('How much did I spend?'), findsOneWidget);
      expect(find.text('Not sent'), findsOneWidget);
    });
  });

  group('the allowance', () {
    testWidgets('is shown, and counts down', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);

      expect(find.text('20/20'), findsOneWidget);

      await AssistantHarness.ask(tester, 'How much did I spend?');

      expect(find.text('19/20'), findsOneWidget);
    });
  });

  group('conversations', () {
    testWidgets('a new one starts empty, keeping the old one', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);
      await AssistantHarness.ask(tester, 'How much did I spend?');

      await tester.tap(find.byTooltip('New conversation'));
      await tester.pumpAndSettle();

      expect(find.text("Hi! I'm your LifePilot assistant."), findsOneWidget);
      expect(find.byType(ChatBubble), findsNothing);

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      expect(find.text('How much did I spend?'), findsOneWidget);
    });

    testWidgets('history lists what was asked, and opens it again', (
      tester,
    ) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 120000)]);
      await AssistantHarness.ask(tester, 'How much did I spend this month?');
      await tester.tap(find.byTooltip('New conversation'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();

      expect(find.text('How much did I spend this month?'), findsOneWidget);
      expect(find.textContaining('1 question'), findsOneWidget);

      await tester.tap(find.text('How much did I spend this month?'));
      await tester.pumpAndSettle();

      // Back on the thread, with both sides of it.
      expect(find.byType(ChatBubble), findsNWidgets(2));
    });

    testWidgets('continuing a conversation adds to the same thread', (
      tester,
    ) async {
      final harness = await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 120000)],
        budgetPlans: [monthlyBudget(500000)],
      );
      await AssistantHarness.ask(tester, 'How much did I spend this month?');
      await AssistantHarness.ask(tester, 'Am I within my budget?');

      expect(harness.container.read(assistantProvider).messages, hasLength(4));
      expect(
        harness.container.read(assistantProvider).conversations,
        hasLength(1),
      );

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 questions'), findsOneWidget);
    });

    testWidgets('deleting one asks first, then removes it', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);
      await AssistantHarness.ask(tester, 'How much did I spend?');

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this conversation?'), findsOneWidget);
      expect(
        find.textContaining(
          'transactions, budgets and goals are not '
          'affected',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Conversation deleted'), findsOneWidget);
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('cancelling the delete keeps it', (tester) async {
      await AssistantHarness.pump(tester, seed: [spend(amount: 1000)]);
      await AssistantHarness.ask(tester, 'How much did I spend?');

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('How much did I spend?'), findsOneWidget);
    });

    testWidgets('an untouched assistant has no history to show', (
      tester,
    ) async {
      await AssistantHarness.pump(tester, route: Routes.assistantHistory);

      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('a conversation survives a relaunch', (tester) async {
      // Words only: the cards are rebuilt from today's figures, never
      // restored from a month ago.
      final store = InMemoryKeyValueStore();

      await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 120000)],
        store: store,
      );
      await AssistantHarness.ask(tester, 'How much did I spend this month?');

      await AssistantHarness.pump(
        tester,
        seed: [spend(amount: 120000)],
        store: store,
        route: Routes.assistantHistory,
      );

      expect(find.text('How much did I spend this month?'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the tab opens the assistant', (tester) async {
      await AssistantHarness.pump(tester, route: Routes.home);

      await tester.tap(find.text('Assistant'));
      await tester.pumpAndSettle();

      expect(find.text("Hi! I'm your LifePilot assistant."), findsOneWidget);
    });

    testWidgets('it is no longer a placeholder', (tester) async {
      await AssistantHarness.pump(tester);

      expect(find.textContaining('Coming in a later phase'), findsNothing);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', AssistantHarness.phone),
      ('a small phone', AssistantHarness.smallPhone),
    ]) {
      testWidgets('the welcome fits $name', (tester) async {
        await AssistantHarness.pump(tester, size: size);
        await AssistantHarness.dragTo(
          tester,
          find.textContaining('nothing leaves your phone'),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('a long answer fits $name', (tester) async {
        await AssistantHarness.pump(
          tester,
          size: size,
          seed: [
            spend(id: 'a', amount: 1200000),
            spend(
              id: 'b',
              amount: 800000,
              categoryId: 'housing',
              categoryLabel: 'Housing',
            ),
            spend(
              id: 'c',
              amount: 450000,
              categoryId: 'transport',
              categoryLabel: 'Transport',
            ),
          ],
          budgetPlans: [monthlyBudget(2000000)],
        );

        await AssistantHarness.ask(
          tester,
          'Give me a summary of my finances this month.',
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
