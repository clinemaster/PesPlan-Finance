import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/config/auth_config.dart';
import 'package:lifepilot_finance/core/router/app_router.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
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
import 'package:lifepilot_finance/features/savings/presentation/providers/savings_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on a settings screen.
///
/// The profile the screens read comes from the onboarding controller, as
/// it does in the app: these tests exercise the settings over a
/// completed setup rather than over a stub.
class SettingsHarness {
  SettingsHarness._(this.container, this.store);

  final ProviderContainer container;

  /// The storage behind the preferences, for relaunch tests.
  final KeyValueStore store;

  /// A configuration with a Google client id in it, for the screens whose
  /// copy differs on a configured build. The repository stays the mock, so
  /// nothing here touches a platform channel.
  static const AuthConfig googleConfigured = AuthConfig(
    serverClientId: '000-test.apps.googleusercontent.com',
  );

  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<SettingsHarness> pump(
    WidgetTester tester, {
    String route = Routes.settings,
    KeyValueStore? store,
    Size size = phone,
    AuthConfig config = const AuthConfig(),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final keyValue = store ?? InMemoryKeyValueStore();

    final transactions = MockTransactionRepository(
      now: () => now,
      seed: const [],
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
    final savings = MockSavingsRepository(now: () => now, delay: Duration.zero);

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        keyValueStoreProvider.overrideWithValue(keyValue),
        authConfigProvider.overrideWithValue(config),
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

    // A completed setup, so the profile the settings read is a real one.
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

    return SettingsHarness._(container, keyValue);
  }

  /// Scrolls the screen until [finder] is visible, if it is not already.
  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).last,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }

  /// Opens one of the hub's rows.
  static Future<void> open(WidgetTester tester, String row) async {
    await scrollTo(tester, find.text(row));
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
