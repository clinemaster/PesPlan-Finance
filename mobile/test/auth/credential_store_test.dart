import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/storage/credential_store.dart';
import 'package:lifepilot_finance/features/onboarding/data/credential_vault.dart';

void main() {
  group('the in-memory store', () {
    test('reads back what was written', () async {
      final store = InMemoryCredentialStore();

      await store.write('k', 'v');

      expect(await store.read('k'), 'v');
    });

    test('reports an absent key as null rather than throwing', () async {
      expect(await InMemoryCredentialStore().read('missing'), isNull);
    });

    test('forgets a deleted key', () async {
      final store = InMemoryCredentialStore();
      await store.write('k', 'v');

      await store.delete('k');

      expect(await store.read('k'), isNull);
    });

    test('deleting something absent is not an error', () async {
      await expectLater(InMemoryCredentialStore().delete('k'), completes);
    });
  });

  group('the vault', () {
    test('keeps the token under one agreed key', () async {
      final store = InMemoryCredentialStore();
      final vault = CredentialVault(store);

      await vault.writeIdToken('token');

      expect(await store.read(CredentialVault.idTokenKey), 'token');
      expect(await vault.readIdToken(), 'token');
    });

    test('writing null clears the stored token', () async {
      // A platform can authenticate without issuing an ID token, and keeping
      // the previous one would leave the app holding a credential for a
      // sign-in that has since been replaced.
      final vault = CredentialVault(InMemoryCredentialStore());
      await vault.writeIdToken('token');

      await vault.writeIdToken(null);

      expect(await vault.readIdToken(), isNull);
    });

    test('clearing leaves nothing behind', () async {
      final vault = CredentialVault(InMemoryCredentialStore());
      await vault.writeIdToken('token');

      await vault.clear();

      expect(await vault.readIdToken(), isNull);
    });

    test('its key is namespaced, so it cannot collide', () async {
      expect(CredentialVault.idTokenKey, startsWith('auth.'));
    });
  });

  group('the failure type', () {
    test('says which operation failed without leaking the value', () {
      const failure = CredentialStoreFailure('write', 'keystore unavailable');

      expect(failure.toString(), contains('write'));
      expect(failure.toString(), contains('keystore unavailable'));
    });
  });
}
