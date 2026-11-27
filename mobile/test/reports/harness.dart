import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
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
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on a reports screen.
///
/// Both repositories are real implementations with zero delay, chained
/// the way production chains them — reports read the transaction
/// repository — so these tests exercise the actual derivation rather than
/// a stubbed report object.
class ReportsHarness {
  ReportsHarness._(this.container);

  final ProviderContainer container;

  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  /// Pinned "now". November is late enough in the year that 2026 is
  /// partly elapsed, which is what makes the in-progress warnings
  /// testable.
  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<ReportsHarness> pump(
    WidgetTester tester, {
    String route = Routes.reports,
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

    // One chain, shared: the reports screen and the dashboard's figures
    // come from the same repository instance, which is what lets a test
    // assert the two agree.
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

    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();

    return ReportsHarness._(container);
  }

  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
