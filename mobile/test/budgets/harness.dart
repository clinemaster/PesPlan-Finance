import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/core/router/app_router.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
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
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on the Budgets tab.
///
/// ## One chain, as production wires it
///
/// Transactions feed reports, reports feed budgets and the dashboard. The
/// harness builds each repository once and hands the same instance to
/// every provider that needs it, because a second instance per provider
/// is exactly how two screens end up reporting different spending for
/// the same month — the bug this chain exists to prevent.
///
/// Sign-in and onboarding are seeded through their controllers rather
/// than walked through the UI, and every repository is zero-delay so
/// nothing waits on a simulated network.
class BudgetsHarness {
  BudgetsHarness._(this.container, this.budgets, this.transactions);

  final ProviderContainer container;

  /// The live mocks, so a test can assert on stored state rather than
  /// only on what happens to be painted.
  final MockBudgetRepository budgets;
  final MockTransactionRepository transactions;

  /// A phone, not the 800x600 default — which is wider and shorter than
  /// any Android device, and hides the overflow worth finding.
  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  /// Pinned "now". Late November, so the month is well under way and a
  /// year has eleven elapsed months behind it.
  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<BudgetsHarness> pump(
    WidgetTester tester, {
    String route = Routes.budgets,
    List<Budget>? plans,
    List<Transaction>? seed,
    Size size = phone,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
      seed: plans,
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
        dashboardRepositoryProvider.overrideWithValue(
          MockDashboardRepository(
            reports: reports,
            transactions: transactions,
            budgets: budgets,
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

    return BudgetsHarness._(container, budgets, transactions);
  }

  /// Scrolls the budgets list far enough to bring [finder] into view.
  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }
}

/// A plan, with only the parts a test cares about spelled out.
Budget plan({
  required int amount,
  String id = 'plan',
  BudgetKind kind = BudgetKind.category,
  String? categoryId = 'food',
  String? categoryLabel = 'Food',
  int year = 2026,
  int month = 11,
  String description = '',
}) => Budget(
  id: id,
  kind: kind,
  amount: Money(amount),
  year: year,
  month: month,
  categoryId: kind == BudgetKind.overall ? null : categoryId,
  categoryLabel: kind == BudgetKind.overall ? null : categoryLabel,
  description: description,
);

/// An overall plan for November 2026.
Budget overallPlan({required int amount, String id = 'overall'}) =>
    plan(amount: amount, id: id, kind: BudgetKind.overall);

/// One expense in November 2026, so spending against a plan is an exact
/// figure rather than whatever the generated history happens to hold.
Transaction spent({
  required int amount,
  String id = 'spend',
  String categoryId = 'food',
  String categoryLabel = 'Food',
  int day = 10,
  String description = 'Shopping',
}) => Transaction.create(
  id: id,
  type: TransactionType.expense,
  magnitudeMinorUnits: amount,
  categoryId: categoryId,
  categoryLabel: categoryLabel,
  date: DateTime(2026, 11, day),
  createdAt: DateTime(2026, 11, day),
  description: description,
);

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
