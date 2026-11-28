import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/router/app_router.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/features/assistant/data/mock_assistant_repository.dart';
import 'package:lifepilot_finance/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget.dart';
import 'package:lifepilot_finance/features/budgets/presentation/providers/budget_providers.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/presentation/providers/report_providers.dart';
import 'package:lifepilot_finance/features/savings/data/mock_savings_repository.dart';
import 'package:lifepilot_finance/features/savings/domain/goal_movement.dart';
import 'package:lifepilot_finance/features/savings/domain/savings_goal.dart';
import 'package:lifepilot_finance/features/savings/presentation/providers/savings_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on the Assistant tab.
///
/// ## The assistant reads the same chain as every other screen
///
/// Transactions feed reports, reports feed budgets, and the assistant
/// reads reports, budgets and savings. The harness builds that chain
/// once and shares it, which is what lets a test assert that an answer
/// quotes the same figure the Reports screen would.
///
/// Animations are off by default: the typing indicator repeats, and a
/// repeating animation means `pumpAndSettle` never settles.
class AssistantHarness {
  AssistantHarness._(this.container, this.store);

  final ProviderContainer container;

  /// The storage behind the conversation history, for relaunch tests.
  final KeyValueStore store;

  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<AssistantHarness> pump(
    WidgetTester tester, {
    String route = Routes.assistant,
    List<Transaction>? seed,
    List<Budget>? budgetPlans,
    List<SavingsGoal>? goals,
    List<GoalMovement>? movements,
    bool shouldFail = false,
    KeyValueStore? store,
    Size size = phone,
    bool animations = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    if (!animations) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    final keyValue = store ?? InMemoryKeyValueStore();

    final transactions = MockTransactionRepository(
      now: () => now,
      seed: seed,
      delay: Duration.zero,
    );
    final reports = MockReportRepository(
      transactions: transactions,
      now: () => now,
      delay: Duration.zero,
    );
    final budgets = MockBudgetRepository(
      reports: reports,
      now: () => now,
      seed: budgetPlans,
      delay: Duration.zero,
    );
    final savings = MockSavingsRepository(
      now: () => now,
      seedGoals: goals,
      seedMovements: movements,
      delay: Duration.zero,
    );

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        keyValueStoreProvider.overrideWithValue(keyValue),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(delay: Duration.zero),
        ),
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        transactionRepositoryProvider.overrideWithValue(transactions),
        reportRepositoryProvider.overrideWithValue(reports),
        budgetRepositoryProvider.overrideWithValue(budgets),
        savingsRepositoryProvider.overrideWithValue(savings),
        assistantRepositoryProvider.overrideWithValue(
          MockAssistantRepository(
            now: () => now,
            reports: reports,
            budgets: budgets,
            savings: savings,
            delay: Duration.zero,
            shouldFail: shouldFail,
          ),
        ),
        dashboardRepositoryProvider.overrideWithValue(
          MockDashboardRepository(
            reports: reports,
            transactions: transactions,
            budgets: budgets,
            savings: savings,
            now: () => now,
            delay: Duration.zero,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(onboardingControllerProvider.notifier).complete();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LifePilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    if (route != Routes.home) {
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
    }

    return AssistantHarness._(container, keyValue);
  }

  /// Types a question and sends it.
  static Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField).last, question);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  /// Sends one of the suggestion chips.
  static Future<void> tapSuggestion(
    WidgetTester tester,
    String question,
  ) async {
    await dragTo(tester, find.text(question));
    await tester.tap(find.text(question).last);
    await tester.pumpAndSettle();
  }

  /// Scrolls the screen until [finder] is visible.
  static Future<void> dragTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).last,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
