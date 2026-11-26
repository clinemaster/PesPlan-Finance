import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:lifepilot_finance/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/reports/data/mock_report_repository.dart';
import 'package:lifepilot_finance/features/reports/presentation/providers/report_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/data/transaction_store.dart';
import 'package:lifepilot_finance/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:material_ui/material_ui.dart';

final DateTime now = DateTime(2026, 11, 26, 9, 30);

/// Starts the app over [store], the way `main()` does.
///
/// Called twice over the same store, this is a relaunch: the widget tree
/// and every provider are rebuilt from nothing, and only what reached
/// disk comes back.
Future<ProviderContainer> start(
  WidgetTester tester,
  KeyValueStore store,
) async {
  tester.view
    ..physicalSize = const Size(393, 851)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final transactions = MockTransactionRepository(
    now: () => now,
    store: TransactionStore(store),
    delay: Duration.zero,
  );
  final reports = MockReportRepository(
    transactions: transactions,
    now: () => now,
    delay: Duration.zero,
  );

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(delay: Duration.zero),
      ),
      transactionRepositoryProvider.overrideWithValue(transactions),
      reportRepositoryProvider.overrideWithValue(reports),
      dashboardRepositoryProvider.overrideWithValue(
        MockDashboardRepository(
          reports: reports,
          transactions: transactions,
          now: () => now,
          delay: Duration.zero,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const LifePilotApp(),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

/// Walks the whole setup flow, as a first-time user would.
Future<void> completeOnboarding(WidgetTester tester) async {
  await tester.tap(find.text('Continue with Google'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start using LifePilot'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a first launch starts at the welcome screen', (tester) async {
    await start(tester, InMemoryKeyValueStore());

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('a relaunch after setup goes straight to the dashboard', (
    tester,
  ) async {
    // The behaviour all of this exists for.
    final store = InMemoryKeyValueStore();

    await start(tester, store);
    await completeOnboarding(tester);
    expect(find.textContaining('Amina'), findsWidgets);

    await start(tester, store);

    expect(
      find.text('Continue with Google'),
      findsNothing,
      reason: 'a returning user should not meet the front door again',
    );
    expect(find.textContaining('Amina'), findsWidgets);
    expect(find.text('Net this month'), findsOneWidget);
  });

  testWidgets('no welcome screen flashes on the way', (tester) async {
    // Restoring synchronously inside build() is what avoids this. An
    // async bootstrap would paint welcome for a frame first.
    final store = InMemoryKeyValueStore();
    await start(tester, store);
    await completeOnboarding(tester);

    await start(tester, store);
    // The very first frame, before anything settles.
    await tester.pump();

    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('a transaction recorded before a relaunch is still there', (
    tester,
  ) async {
    final store = InMemoryKeyValueStore();

    await start(tester, store);
    await completeOnboarding(tester);

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '34500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nyama choma');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    // It reached disk, which is the part persistence is responsible for.
    expect(
      TransactionStore(store).read().map((t) => t.description),
      contains('Nyama choma'),
    );

    // And it comes back on the next launch, on screen rather than only
    // in storage.
    //
    // Asserted by what is rendered, not by awaiting a provider's future:
    // on a container that has not been pumped yet, `read(p.future)`
    // creates a timer the fake clock never advances, and the await
    // deadlocks.
    await start(tester, store);
    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nyama choma'), findsOneWidget);
    expect(find.text('-TSh 34,500'), findsOneWidget);
  });

  testWidgets('the dashboard updates when a transaction is recorded', (
    tester,
  ) async {
    // The dashboard derives its figures from transactions now, so it has
    // to notice when they change — otherwise a user records an expense
    // from the dashboard's own quick action, lands back on it, and finds
    // the totals unmoved.
    final store = InMemoryKeyValueStore();
    final container = await start(tester, store);
    await completeOnboarding(tester);

    final before = container.read(dashboardProvider).value!.expenses;

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    final after = container.read(dashboardProvider).value!.expenses;

    expect(
      after.minorUnits,
      before.minorUnits + 50000,
      reason: 'the dashboard should have picked up the new expense',
    );
  });

  testWidgets('signing out returns to the welcome screen and stays there', (
    tester,
  ) async {
    final store = InMemoryKeyValueStore();

    await start(tester, store);
    await completeOnboarding(tester);

    await tester.tap(find.bySemanticsLabel('Profile and settings'));
    await tester.pumpAndSettle();
    final signOut = find.widgetWithText(AppButton, 'Sign out');
    await tester.scrollUntilVisible(
      signOut,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut.last);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);

    await start(tester, store);
    expect(
      find.text('Continue with Google'),
      findsOneWidget,
      reason: 'signing out must survive a relaunch too',
    );
  });

  testWidgets('the theme choice survives a relaunch', (tester) async {
    final store = InMemoryKeyValueStore();

    final first = await start(tester, store);
    await completeOnboarding(tester);
    first.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await tester.pumpAndSettle();

    final second = await start(tester, store);
    expect(second.read(themeModeProvider), ThemeMode.dark);
  });
}
