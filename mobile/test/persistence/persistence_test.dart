import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/app.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/core/time/clock.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/data/session_store.dart';
import 'package:lifepilot_finance/features/onboarding/domain/app_language.dart';
import 'package:lifepilot_finance/features/onboarding/domain/country.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lifepilot_finance/features/transactions/data/mock_transaction_repository.dart';
import 'package:lifepilot_finance/features/transactions/data/transaction_store.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction_filter.dart';
import 'package:material_ui/material_ui.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

/// One container, as one run of the app.
///
/// Relaunching is modelled by disposing a container and building another
/// over the same store — which is exactly what a restart is: the process
/// goes, the disk stays.
ProviderContainer launch(KeyValueStore store) {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => today),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Transaction make(String id, int magnitude) => Transaction.create(
  id: id,
  type: TransactionType.expense,
  magnitudeMinorUnits: magnitude,
  categoryId: 'food',
  categoryLabel: 'Food',
  description: 'Lunch',
  date: today,
  createdAt: today,
);

void main() {
  group('the session survives a relaunch', () {
    test('a signed-in user is still signed in', () async {
      final store = InMemoryKeyValueStore();

      final first = launch(store);
      await first.read(authControllerProvider.notifier).signInWithGoogle();
      expect(first.read(authControllerProvider), isA<AuthAuthenticated>());
      first.dispose();

      final second = launch(store);
      expect(
        second.read(authControllerProvider),
        isA<AuthAuthenticated>(),
        reason: 'the whole point: a restart should not sign anyone out',
      );
      expect(
        second.read(currentUserProvider)!.email,
        MockAuthRepository.demoUser.email,
      );
    });

    test('a finished setup is not run again', () async {
      final store = InMemoryKeyValueStore();

      final first = launch(store);
      await first.read(authControllerProvider.notifier).signInWithGoogle();
      first.read(onboardingControllerProvider.notifier).complete();
      first.dispose();

      final second = launch(store);
      expect(second.read(onboardingControllerProvider).completed, isTrue);
    });

    test('the answers the user gave come back, not the ones Google gave',
        () async {
      // Seeding from the identity on every launch would quietly undo
      // every edit the user made during setup.
      final store = InMemoryKeyValueStore();

      final first = launch(store);
      await first.read(authControllerProvider.notifier).signInWithGoogle();
      final controller = first.read(onboardingControllerProvider.notifier);
      controller
        ..updateName('Juma Mushi')
        ..updatePhone('+255712345678')
        ..updateCountry(Country.kenya)
        ..updateLanguage(AppLanguage.swahili)
        ..complete();
      first.dispose();

      final second = launch(store);
      final draft = second.read(onboardingControllerProvider).draft!;

      expect(draft.name, 'Juma Mushi');
      expect(draft.phone, '+255712345678');
      expect(draft.country, Country.kenya);
      expect(draft.currency, Currency.kes, reason: 'followed the country');
      expect(draft.language, AppLanguage.swahili);
    });

    test('an edit made after setup persists', () async {
      final store = InMemoryKeyValueStore();

      final first = launch(store);
      await first.read(authControllerProvider.notifier).signInWithGoogle();
      first.read(onboardingControllerProvider.notifier)
        ..complete()
        ..updateName('Renamed Later');
      first.dispose();

      expect(
        launch(store).read(onboardingControllerProvider).draft!.name,
        'Renamed Later',
      );
    });

    test('an abandoned setup leaves nothing behind', () async {
      // Nothing is written until complete(), so a user who signs in and
      // backs out does not leave a half-filled profile on the device.
      final store = InMemoryKeyValueStore();

      final container = launch(store);
      await container.read(authControllerProvider.notifier).signInWithGoogle();
      container.read(onboardingControllerProvider.notifier).updateName('Half');

      expect(SessionStore(store).readProfile(), isNull);
      expect(SessionStore(store).readCompleted(), isFalse);
    });

    test('signing out forgets the session entirely', () async {
      final store = InMemoryKeyValueStore();

      final first = launch(store);
      await first.read(authControllerProvider.notifier).signInWithGoogle();
      first.read(onboardingControllerProvider.notifier).complete();
      await first.read(authControllerProvider.notifier).signOut();
      first.dispose();

      final second = launch(store);
      expect(second.read(authControllerProvider), isA<AuthIdle>());
      expect(second.read(onboardingControllerProvider).hasDraft, isFalse);
      expect(second.read(onboardingControllerProvider).completed, isFalse);
      expect(
        SessionStore(store).readProfile(),
        isNull,
        reason: 'a signed-out device should not keep a name lying about',
      );
    });
  });

  group('transactions survive a relaunch', () {
    test('a first launch generates history and stores it', () {
      final store = InMemoryKeyValueStore();
      final transactionStore = TransactionStore(store);

      expect(transactionStore.hasStoredData, isFalse);

      final repository = MockTransactionRepository(
        now: () => today,
        store: transactionStore,
        delay: Duration.zero,
      );

      expect(repository.all, isNotEmpty);
      expect(transactionStore.hasStoredData, isTrue);
    });

    test('a second launch reads what was stored rather than regenerating',
        () async {
      final store = InMemoryKeyValueStore();

      final first = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      final before = first.all.map((t) => t.id).toList();

      final second = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );

      expect(second.all.map((t) => t.id), before);
    });

    test('an added transaction is there next launch', () async {
      final store = InMemoryKeyValueStore();

      final first = MockTransactionRepository(
        now: () => today,
        seed: const [],
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      await first.add(make('new', 25000));

      final second = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );

      expect(second.all, hasLength(1));
      expect(second.all.single.id, 'new');
      expect(second.all.single.amount.minorUnits, -25000);
      expect(second.all.single.description, 'Lunch');
    });

    test('an edit survives', () async {
      final store = InMemoryKeyValueStore();

      final first = MockTransactionRepository(
        now: () => today,
        seed: [make('x', 1000)],
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      await first.add(make('x', 1000));
      await first.update(make('x', 7777));

      final second = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      expect(
        second.all.firstWhere((t) => t.id == 'x').amount.minorUnits,
        -7777,
      );
    });

    test('a deletion survives', () async {
      final store = InMemoryKeyValueStore();

      final first = MockTransactionRepository(
        now: () => today,
        seed: [make('a', 1000), make('b', 2000)],
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      await first.add(make('a', 1000));
      await first.delete('a');

      final second = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      expect(second.all.map((t) => t.id), isNot(contains('a')));
    });

    test('deleting everything does not bring the seed back', () async {
      // Without a "something was written" marker, clearing the last
      // transaction would make the app helpfully regenerate three years
      // of history the user had just removed.
      final store = InMemoryKeyValueStore();

      final first = MockTransactionRepository(
        now: () => today,
        seed: [make('only', 500)],
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      await first.add(make('only', 500));
      await first.delete('only');

      final second = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );
      expect(second.all, isEmpty);
    });

    test('every field makes the round trip intact', () async {
      final store = InMemoryKeyValueStore();
      final original = Transaction.create(
        id: 'round-trip',
        type: TransactionType.income,
        magnitudeMinorUnits: 1234567,
        categoryId: 'freelance',
        categoryLabel: 'Freelance',
        description: 'Website for Mama Lishe',
        date: DateTime(2025, 3, 14),
        createdAt: DateTime(2025, 3, 14, 9, 30),
        currency: Currency.kes,
      );

      await TransactionStore(store).write([original]);
      final restored = TransactionStore(store).read().single;

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.amount.minorUnits, original.amount.minorUnits);
      expect(restored.amount.currency, Currency.kes);
      expect(restored.categoryId, original.categoryId);
      expect(restored.categoryLabel, original.categoryLabel);
      expect(restored.description, original.description);
      expect(restored.date, original.date);
      expect(restored.createdAt, original.createdAt);
    });

    test('the stored list is what the repository reports', () async {
      final store = InMemoryKeyValueStore();
      final repository = MockTransactionRepository(
        now: () => today,
        store: TransactionStore(store),
        delay: Duration.zero,
      );

      final listed = await repository.list(TransactionFilter.none);
      expect(TransactionStore(store).read(), hasLength(listed.totalCount));
    });
  });

  group('preferences survive a relaunch', () {
    test('the theme choice comes back', () {
      final store = InMemoryKeyValueStore();

      launch(store).read(themeModeProvider.notifier).set(ThemeMode.dark);

      expect(launch(store).read(themeModeProvider), ThemeMode.dark);
    });

    test('an untouched theme follows the system', () {
      expect(
        launch(InMemoryKeyValueStore()).read(themeModeProvider),
        ThemeMode.system,
      );
    });
  });

  group('unreadable stored state does not break the app', () {
    // A crash on launch is unrecoverable for the user; signing in again
    // is not. So corrupt state is treated as absent.
    test('a damaged session reads as no session', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('session.user', 'not json at all');

      expect(SessionStore(store).readUser(), isNull);
      expect(launch(store).read(authControllerProvider), isA<AuthIdle>());
    });

    test('a damaged profile reads as no profile', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('session.profile', '{"name":');

      expect(SessionStore(store).readProfile(), isNull);
    });

    test('a damaged transaction list reads as empty', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('transactions.all', '[[[');

      expect(TransactionStore(store).read(), isEmpty);
    });

    test('an unknown currency code falls back rather than failing', () async {
      final store = InMemoryKeyValueStore();
      await store.setString(
        'transactions.all',
        '[{"id":"a","type":"expense","amount":-100,"currency":"XXX",'
            '"categoryId":"food","categoryLabel":"Food","description":"",'
            '"date":"2026-11-26T00:00:00.000","createdAt":'
            '"2026-11-26T00:00:00.000"}]',
      );

      expect(TransactionStore(store).read().single.amount.currency,
          Currency.tzs);
    });
  });
}
