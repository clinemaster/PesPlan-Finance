import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/app_language.dart';
import '../domain/auth_user.dart';
import '../domain/country.dart';
import '../domain/user_profile.dart';

/// Keeps the session and the profile between launches.
///
/// ## Why this is not storing a credential
///
/// What is kept here is a name, an email and the answers the user gave
/// during setup. All of it is already on screen whenever the app is open,
/// and none of it unlocks anything. The Google ID token is not here: it
/// goes to `CredentialVault`, over the keystore, through an interface this
/// class has no access to.
///
/// ## Why reads are synchronous and writes are not
///
/// A controller restores itself inside `build()`, so a relaunch goes
/// straight to the right screen instead of showing a signed-out welcome
/// for a frame. Writes can take their time; nothing waits on them.
class SessionStore {
  const SessionStore(this._store);

  final KeyValueStore _store;

  static const String _userKey = 'session.user';
  static const String _profileKey = 'session.profile';
  static const String _completedKey = 'session.onboardingComplete';

  /// Everything this store owns, so signing out can clear it in one go.
  static bool ownsKey(String key) => key.startsWith('session.');

  // ------------------------------------------------------------- reading

  AuthUser? readUser() {
    final raw = _store.getString(_userKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
      );
    } on Object {
      // Stored state from an older build, or a partial write. Treated as
      // "no session" rather than crashing on launch — the worst case is
      // the user signs in again, which is recoverable; a crash loop on
      // start is not.
      return null;
    }
  }

  UserProfile? readProfile() {
    final raw = _store.getString(_profileKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile(
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        country: _countryFor(json['country'] as String?),
        currency: _currencyFor(json['currency'] as String?),
        language: _languageFor(json['language'] as String?),
      );
    } on Object {
      return null;
    }
  }

  bool readCompleted() => _store.getString(_completedKey) == 'true';

  // ------------------------------------------------------------- writing

  Future<void> writeUser(AuthUser user) => _store.setString(
    _userKey,
    jsonEncode({
      'id': user.id,
      'displayName': user.displayName,
      'email': user.email,
    }),
  );

  Future<void> writeProfile(UserProfile profile) => _store.setString(
    _profileKey,
    jsonEncode({
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'country': profile.country.code,
      'currency': profile.currency.code,
      'language': profile.language.code,
    }),
  );

  Future<void> writeCompleted(bool completed) =>
      _store.setString(_completedKey, completed ? 'true' : 'false');

  /// Forgets the session entirely. Used on sign-out.
  Future<void> clear() => _store.removeWhere(ownsKey);

  // ------------------------------------------------------------ decoding
  //
  // Each falls back to the launch-market default rather than failing. A
  // code that no longer exists — a currency dropped between builds —
  // should leave the user with a working app and a sensible default, not
  // a blank screen.

  static Country _countryFor(String? code) {
    for (final country in Country.supported) {
      if (country.code == code) return country;
    }
    return Country.initial;
  }

  static Currency _currencyFor(String? code) {
    for (final currency in Currency.supported) {
      if (currency.code == code) return currency;
    }
    return Currency.tzs;
  }

  static AppLanguage _languageFor(String? code) {
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return AppLanguage.initial;
  }
}
