import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere small and non-sensitive to keep things between launches.
///
/// ## Why an interface over `SharedPreferences` directly
///
/// Two reasons. Tests get an in-memory implementation and never touch a
/// real platform channel, which keeps them fast and independent of each
/// other. And when some of this moves — transactions to a database once
/// there is a server to cache — the move happens behind this interface
/// rather than in every caller.
///
/// ## What must never go in here
///
/// Credentials. `SharedPreferences` is an unencrypted XML file on Android,
/// readable on a rooted device and in some backups. The signed-in user is
/// fine — it is a name and an email with no secret attached — but the
/// Google ID token goes to `CredentialStore` and the Android keystore
/// instead. This interface deliberately has no "secure" flag: the two are
/// different types, so no caller can reach for the wrong one, and a screen
/// is never handed the one that holds a credential.
abstract interface class KeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);

  /// Everything under a prefix, for clearing a feature's state at once.
  Future<void> removeWhere(bool Function(String key) test);
}

/// The default. Holds nothing between launches, which is exactly right for
/// a test and exactly wrong for the app — so the app overrides it.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeWhere(bool Function(String key) test) async =>
      _values.keys.where(test).toList().forEach(_values.remove);
}

/// The real one.
///
/// Reads are synchronous because `SharedPreferences` keeps its values in
/// memory once loaded. That matters: it lets a controller restore its
/// state inside `build()` rather than through an async bootstrap, so the
/// app never shows a signed-out welcome screen for a frame before
/// discovering it has a session.
class SharedPreferencesStore implements KeyValueStore {
  const SharedPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  @override
  Future<void> removeWhere(bool Function(String key) test) async {
    for (final key in _preferences.getKeys().where(test).toList()) {
      await _preferences.remove(key);
    }
  }
}

/// Where persisted state lives.
///
/// Defaults to in-memory so a test gets a clean, isolated store without
/// arranging anything. `main()` overrides it with the real one.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => InMemoryKeyValueStore(),
);
