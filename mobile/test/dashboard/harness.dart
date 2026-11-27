import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/features/budgets/data/mock_budget_repository.dart';
import 'package:lifepilot_finance/features/budgets/presentation/providers/budget_providers.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/savings/data/mock_savings_repository.dart';
import 'package:lifepilot_finance/features/savings/presentation/providers/savings_providers.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/presentation/providers/report_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app straight into the dashboard.
///
/// Sign-in and onboarding are driven through their own controllers rather
/// than through the UI: these tests are about the dashboard, and walking
/// four onboarding screens before every one of them would make the suite
/// slow and would fail them for reasons that have nothing to do with the
/// dashboard. The onboarding tests already cover that path end to end.
///
/// The clock is pinned so the greeting is deterministic, and the repository
/// is zero-delay so tests are not waiting on a simulated network.
class DashboardHarness {
  DashboardHarness._(this.container);

  final ProviderContainer container;

  /// A phone, not the 800x600 default.
  ///
  /// The default test surface is wider and shorter than any Android device,
  /// which hides exactly the overflow this layout needs to be checked for.
  static const Size phone = Size(393, 851);

  /// A deliberately small device — the narrowest still in common use in the
  /// launch market.
  static const Size smallPhone = Size(320, 568);

  static Future<DashboardHarness> pump(
    WidgetTester tester, {
    MockDataMode data = MockDataMode.populated,
    Size size = phone,
    DateTime? now,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    DateTime clock() => now ?? DateTime(2026, 11, 26, 9, 30);

    final transactions = MockTransactionRepository(
      now: clock,
      delay: Duration.zero,
    );

    // Built once and shared, exactly as the app wires them: reports read
    // transactions, budgets read reports, the dashboard reads both. A
    // second instance per provider would leave the screens reading
    // different objects, which is the disagreement this chain removes.
    final reports = MockReportRepository(
      transactions: transactions,
      now: clock,
      delay: Duration.zero,
    );

    final budgets = MockBudgetRepository(
      reports: reports,
      now: clock,
      delay: Duration.zero,
    );

    final savings = MockSavingsRepository(now: clock, delay: Duration.zero);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(delay: Duration.zero),
        ),
        // Start already signed in, synchronously.
        //
        // Calling signInWithGoogle() here would hang: inside testWidgets the
        // clock is fake, and a `Future.delayed` before the first pump has
        // nothing to advance it. Seeding the state is also closer to what
        // these tests mean — "a signed-in user opens the dashboard" — than
        // replaying a sign-in the onboarding suite already covers.
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        transactionRepositoryProvider.overrideWithValue(transactions),
        // Overridden even though the dashboard is what is under test: the
        // budget card reads the budgets feature, and the default
        // repositories carry a quarter-second delay that a fake clock
        // never advances, which leaves a pending timer at teardown.
        reportRepositoryProvider.overrideWithValue(reports),
        budgetRepositoryProvider.overrideWithValue(budgets),
        savingsRepositoryProvider.overrideWithValue(savings),
        dashboardRepositoryProvider.overrideWithValue(
          MockDashboardRepository(
            reports: reports,
            transactions: transactions,
            budgets: budgets,
            savings: savings,
            now: clock,
            delay: Duration.zero,
          ),
        ),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    container.read(mockDataModeProvider.notifier).select(data);

    // The draft is seeded from auth; this marks setup finished so the
    // router's guard lets the dashboard through.
    container.read(onboardingControllerProvider.notifier).complete();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LifePilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    return DashboardHarness._(container);
  }

  /// Scrolls the dashboard far enough to bring [finder] into view.
  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
}

/// An [AuthController] that is already authenticated when built.
class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
