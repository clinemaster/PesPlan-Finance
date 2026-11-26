import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/router/app_router.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on the Transactions tab.
///
/// Sign-in and onboarding are seeded through their controllers rather than
/// walked through the UI: these tests are about transactions, and replaying
/// four onboarding screens before each one would make them slow and fail
/// them for unrelated reasons. The onboarding suite already covers that
/// path end to end.
///
/// The clock is pinned so "Today" and "Yesterday" are deterministic, and
/// the repositories are zero-delay so nothing waits on a simulated network.
class TransactionsHarness {
  TransactionsHarness._(this.container, this.repository);

  final ProviderContainer container;

  /// The live mock, for asserting on stored state rather than only on
  /// what happens to be painted.
  final MockTransactionRepository repository;

  /// A phone, not the 800x600 default — which is wider and shorter than
  /// any Android device and hides the overflow worth finding.
  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  /// Pinned "now". A Thursday, mid-afternoon, so nothing lands on a
  /// month or year boundary by accident.
  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<TransactionsHarness> pump(
    WidgetTester tester, {
    List<Transaction>? seed,
    Size size = phone,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MockTransactionRepository(
      now: () => now,
      seed: seed,
      delay: Duration.zero,
    );

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(delay: Duration.zero),
        ),
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        dashboardRepositoryProvider.overrideWithValue(
          MockDashboardRepository(
            reports: MockReportRepository(
              transactions: repository,
              now: () => now,
              delay: Duration.zero,
            ),
            transactions: repository,
            now: () => now,
            delay: Duration.zero,
          ),
        ),
        transactionRepositoryProvider.overrideWithValue(repository),
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

    // Straight to the tab under test.
    container.read(routerProvider).go(Routes.transactions);
    await tester.pumpAndSettle();

    return TransactionsHarness._(container, repository);
  }

  /// An account with nothing in it.
  static Future<TransactionsHarness> pumpEmpty(WidgetTester tester) =>
      pump(tester, seed: const []);

  /// Types into the search box and lets the list settle.
  static Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
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

/// An [AuthController] that is already authenticated when built.
///
/// Calling signInWithGoogle() before the first pump would hang: inside
/// testWidgets the clock is fake, and a `Future.delayed` has nothing to
/// advance it.
class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(MockAuthRepository.demoUser);
}
