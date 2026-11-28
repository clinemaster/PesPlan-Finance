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
import 'package:lifepilot_finance/features/savings/data/mock_savings_repository.dart';
import 'package:lifepilot_finance/features/savings/presentation/providers/savings_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:lifepilot_finance/features/voice/data/mock_voice_repository.dart';
import 'package:lifepilot_finance/features/voice/presentation/providers/voice_providers.dart';
import 'package:lifepilot_finance/features/voice/presentation/widgets/voice_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Boots the real app on the voice screen.
///
/// ## Animations are off by default here
///
/// The microphone pulses while listening, and a repeating animation means
/// `pumpAndSettle` never settles. Tests run with the platform's
/// reduced-motion flag set, which is both what a real device with that
/// accessibility setting reports and what makes the rest of the suite
/// readable. One test turns it back on to check the animation actually
/// runs.
class VoiceHarness {
  VoiceHarness._(this.container, this.voice, this.transactions);

  final ProviderContainer container;

  /// The live mocks, so a test can assert on what was heard and on what
  /// was saved rather than only on what is painted.
  final MockVoiceRepository voice;
  final MockTransactionRepository transactions;

  static const Size phone = Size(393, 851);
  static const Size smallPhone = Size(320, 568);

  static final DateTime now = DateTime(2026, 11, 26, 15, 30);

  static Future<VoiceHarness> pump(
    WidgetTester tester, {
    String route = Routes.addVoice,
    VoiceScenario? scenario = VoiceScenario.clearExpense,
    List<Transaction>? seed = const [],
    Size size = phone,
    bool animations = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    if (!animations) {
      // Reduced motion, as a device with that accessibility setting
      // reports it.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

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
      delay: Duration.zero,
    );
    final savings = MockSavingsRepository(now: () => now, delay: Duration.zero);
    final voice = MockVoiceRepository(
      now: () => now,
      scenario: scenario,
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
        voiceRepositoryProvider.overrideWithValue(voice),
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

    return VoiceHarness._(container, voice, transactions);
  }

  /// Speaks for [seconds], then stops.
  ///
  /// `pump`, never `pumpAndSettle`, while the microphone is open: the
  /// controller ticks once a second, and settling would wait for a timer
  /// that keeps rescheduling itself.
  /// Presses the microphone itself — "Tap to start" is the label under
  /// it, not the control.
  static Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byType(MicButton));
    await tester.pump();
  }

  static Future<void> speak(WidgetTester tester, {int seconds = 3}) async {
    await tapMic(tester);

    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text('Stop and continue'));
    await tester.pumpAndSettle();
  }

  /// The whole way from the microphone to the review card.
  static Future<void> speakAndContinue(
    WidgetTester tester, {
    int seconds = 3,
  }) async {
    await speak(tester, seconds: seconds);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  /// Scrolls a pushed route, which has several Scrollables behind it.
  static Future<void> dragTo(WidgetTester tester, Finder finder) async {
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
