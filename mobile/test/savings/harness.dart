import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/core/router/app_router.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
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
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on the Goals tab.
///
/// One chain, built once and shared, as production wires it: reports read
/// transactions, budgets read reports, and the dashboard reads all of
/// them plus savings. Savings stand apart on purpose — a contribution is
/// not a transaction — so the repository is independent, which is exactly
/// what these tests check.
class SavingsHarness {
  SavingsHarness._(this.container, this.savings);

  final ProviderContainer container;

  /// The live mock, so a test can assert on stored state rather than
  /// only on what happens to be painted.
  final MockSavingsRepository savings;

  /// A phone, not the 800x600 default — which is wider and shorter than
  /// any Android device, and hides the overflow worth finding.
  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  /// Pinned "now". Late November, so a target date in March is a few
  /// months out and one in December is weeks away.
  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<SavingsHarness> pump(
    WidgetTester tester, {
    String route = Routes.goals,
    List<SavingsGoal>? goals,
    List<GoalMovement>? movements,
    Size size = phone,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final transactions = MockTransactionRepository(
      now: () => now,
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
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(delay: Duration.zero),
        ),
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        transactionRepositoryProvider.overrideWithValue(transactions),
        reportRepositoryProvider.overrideWithValue(reports),
        budgetRepositoryProvider.overrideWithValue(budgets),
        savingsRepositoryProvider.overrideWithValue(savings),
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

    return SavingsHarness._(container, savings);
  }

  /// Scrolls the screen far enough to bring [finder] into view.
  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls a route pushed over the shell — a form, or the goal detail
  /// screen.
  ///
  /// `scrollUntilVisible` cannot be used there: several Scrollables are
  /// in the tree at once (the shell's branches sit behind the pushed
  /// route) and the one it resolves to has no element, which fails with
  /// a bare "Bad state: No element". Dragging the pushed route's own
  /// list is unambiguous.
  static Future<void> dragTo(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).last,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }

  /// Back to the top of a screen the test has already scrolled down: a
  /// pushed route keeps its offset while a form is opened over it and
  /// popped again, so the summary card is not where it started.
  static Future<void> scrollToTop(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await tester.pumpAndSettle();
    }
  }
}

/// A goal, with only the parts a test cares about spelled out.
SavingsGoal goal({
  required int target,
  String id = 'goal',
  String name = 'Emergency fund',
  String iconKey = 'savings',
  DateTime? targetDate,
  DateTime? createdAt,
  String description = '',
}) => SavingsGoal(
  id: id,
  name: name,
  target: Money(target),
  createdAt: createdAt ?? DateTime(2026, 6, 12),
  iconKey: iconKey,
  targetDate: targetDate,
  description: description,
);

/// Money into a goal, so a balance is an exact figure rather than
/// whatever the demo history happens to hold.
GoalMovement paidIn({
  required int amount,
  String id = 'in',
  String goalId = 'goal',
  int day = 10,
  String description = '',
}) => GoalMovement(
  id: id,
  goalId: goalId,
  kind: MovementKind.contribution,
  amount: Money(amount),
  date: DateTime(2026, 11, day),
  recordedAt: DateTime(2026, 11, day),
  description: description,
);

/// Money back out of a goal.
GoalMovement tookOut({
  required int amount,
  String id = 'out',
  String goalId = 'goal',
  int day = 12,
  String description = '',
}) => GoalMovement(
  id: id,
  goalId: goalId,
  kind: MovementKind.withdrawal,
  amount: Money(amount),
  date: DateTime(2026, 11, day),
  recordedAt: DateTime(2026, 11, day),
  description: description,
);

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
