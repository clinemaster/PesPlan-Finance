import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/config/auth_config.dart';
import 'package:lifepilot_finance/core/storage/credential_store.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/features/onboarding/data/credential_vault.dart';
import 'package:lifepilot_finance/features/onboarding/data/google_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/data/mock_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/data/session_store.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_user.dart';
import 'package:lifepilot_finance/features/onboarding/domain/session_restore.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/auth_providers.dart';

import 'fakes.dart';

const AuthUser _storedUser = AuthUser(
  id: 'google-uid-1',
  displayName: 'Amina Hassan',
  email: 'amina.hassan@gmail.com',
);

ProviderContainer _container({
  AuthConfig config = const AuthConfig(),
  KeyValueStore? store,
  RecordingAuthRepository? repository,
  CredentialStore? credentials,
}) {
  final container = ProviderContainer(
    overrides: [
      authConfigProvider.overrideWithValue(config),
      if (store != null) keyValueStoreProvider.overrideWithValue(store),
      if (credentials != null)
        credentialStoreProvider.overrideWithValue(credentials),
      if (repository != null)
        authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('choosing a repository', () {
    test('an unconfigured build gets the mock', () {
      final container = _container();

      expect(container.read(authRepositoryProvider), isA<MockAuthRepository>());
    });

    test('a configured build gets the Google one', () {
      // The whole of the Phase 12 swap: one provider, one switch, and
      // nothing above it knows which arm it took.
      final container = _container(
        config: const AuthConfig(
          serverClientId: '000-test.apps.googleusercontent.com',
        ),
      );

      expect(
        container.read(authRepositoryProvider),
        isA<GoogleAuthRepository>(),
      );
    });

    test('the Google repository is handed the credential store', () async {
      // Not the preferences store. The two are different interfaces, and
      // this is the one wiring that decides which of them a credential
      // reaches — worth pinning rather than assuming.
      final credentials = InMemoryCredentialStore();
      await credentials.write(CredentialVault.idTokenKey, 'planted');

      final container = _container(
        config: const AuthConfig(requested: 'google'),
        credentials: credentials,
      );

      final repository =
          container.read(authRepositoryProvider) as GoogleAuthRepository;

      expect(await repository.vault.readIdToken(), 'planted');
    });
  });

  group('the launch refresh', () {
    test('does nothing when nobody is signed in', () async {
      final repository = RecordingAuthRepository();
      final container = _container(repository: repository);

      final outcome = await container
          .read(authControllerProvider.notifier)
          .refreshSession();

      expect(outcome, SessionRestore.needsUser);
      expect(repository.restoreCalls, 0);
    });

    test(
      'asks the provider for a fresh credential for a stored session',
      () async {
        final store = InMemoryKeyValueStore();
        await SessionStore(store).writeUser(_storedUser);

        final repository = RecordingAuthRepository();
        final container = _container(store: store, repository: repository);

        final outcome = await container
            .read(authControllerProvider.notifier)
            .refreshSession();

        expect(outcome, SessionRestore.refreshed);
        expect(repository.restoreCalls, 1);
      },
    );

    test('leaves the session alone when the provider cannot help', () async {
      // The argument in SessionRestore: a refresh that fails must never
      // return someone to a sign-in screen, because the provider cannot tell
      // a revoked account from a phone in a tunnel.
      final store = InMemoryKeyValueStore();
      await SessionStore(store).writeUser(_storedUser);

      final container = _container(
        store: store,
        repository: RecordingAuthRepository(
          restore: SessionRestore.unavailable,
        ),
      );
      final controller = container.read(authControllerProvider.notifier);

      await controller.refreshSession();

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(container.read(currentUserProvider), _storedUser);
    });

    test('the mock answers honestly that it has nothing to refresh', () async {
      final store = InMemoryKeyValueStore();
      await SessionStore(store).writeUser(_storedUser);

      final container = _container(store: store);

      expect(
        await container.read(authControllerProvider.notifier).refreshSession(),
        SessionRestore.needsUser,
      );
    });
  });
}
