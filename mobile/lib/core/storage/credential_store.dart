import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Somewhere to keep a secret.
///
/// ## Why this is not the key-value store
///
/// `KeyValueStore` is an unencrypted XML file on Android, and it says in its
/// own documentation that credentials must not go in it. Rather than add a
/// "secure" flag to that interface — which would put the right and wrong
/// choice one boolean apart, and make the wrong one the default — a
/// credential goes through a different door. The two interfaces are
/// deliberately not interchangeable: nothing can accidentally write a token
/// to preferences, because preferences do not have this type.
///
/// ## Why every method is asynchronous
///
/// Decryption is not free and the platform does it off the main thread.
/// `KeyValueStore` can read synchronously because its values are already in
/// memory; this cannot, which is why no controller restores itself from a
/// credential. The session that decides which screen the app opens on comes
/// from preferences, and the credential is read later by whatever needs to
/// make a call with it.
abstract interface class CredentialStore {
  /// The stored value, or null if there is none.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// A credential could not be stored or retrieved.
///
/// Thrown rather than swallowed, because a caller's correct response differs:
/// a failed read is usually "ask the user to sign in again", while a failed
/// write means the credential this device holds is not the one the provider
/// thinks it issued, and the sign-in should not be reported as complete.
class CredentialStoreFailure implements Exception {
  const CredentialStoreFailure(this.operation, this.cause);

  /// `read`, `write` or `delete`. Diagnostic, never shown to a user.
  final String operation;

  final Object cause;

  @override
  String toString() => 'CredentialStoreFailure($operation): $cause';
}

/// The default. Holds nothing between launches.
///
/// Right for a test, and right for the mock provider, which has no
/// credential to keep. The app overrides it with [SecureCredentialStore].
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// The real one: the Android keystore, and the iOS keychain.
///
/// ## Reads degrade, writes do not
///
/// An unreadable entry is a known Android situation — a restore onto a new
/// device brings the encrypted value without the hardware key that decrypts
/// it — and the right answer is to treat it as absent and have the user sign
/// in again, not to crash on launch. (The manifest excludes this store from
/// backup so it should not arise; this is the belt to that braces.) A failed
/// *write* is different and is reported, because the alternative is telling
/// someone they are signed in while holding nothing.
class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore(this._storage);

  /// Defaults are the plugin's recommended ciphers: an RSA-wrapped AES-GCM
  /// key in the Android keystore. No biometric gate — the app has no app
  /// lock yet, and a prompt on a token read would appear at launch with no
  /// explanation for it.
  factory SecureCredentialStore.standard() =>
      const SecureCredentialStore(FlutterSecureStorage());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (error) {
      debugPrint('CredentialStore: could not read $key ($error)');
      // Leave nothing undecryptable behind to fail again next launch.
      try {
        await _storage.delete(key: key);
      } on Object {
        // Nothing further to try; the value stays and reads keep failing
        // into this same branch, which is survivable.
      }
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (error) {
      throw CredentialStoreFailure('write', error);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error) {
      throw CredentialStoreFailure('delete', error);
    }
  }
}

/// Where credentials live.
///
/// In-memory by default so a test never opens a platform channel, and so a
/// mock-provider build carries no keystore dependency it does not use.
/// `main()` overrides it with [SecureCredentialStore].
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => InMemoryCredentialStore(),
);
