import '../../../core/storage/credential_store.dart';

/// The auth feature's view of secure storage.
///
/// One class per thing stored, with the key names in one place — the same
/// shape as `SessionStore` over preferences, for the same reason: a key
/// spelled differently in two files is a bug that only shows up as a user
/// being asked to sign in again.
///
/// ## What is in here
///
/// An ID token, and nothing else. It is a signed assertion from Google that
/// this person is who they say they are, valid for about an hour, and it is
/// what the Django backend will verify in a later phase instead of trusting
/// the app's word about who is calling. There is no refresh token: the
/// Android flow does not hand one to the client, and a token this short-lived
/// is reissued by asking Google again rather than by being refreshed here.
///
/// ## Why it is stored at all, given nothing reads it yet
///
/// Because the alternative is discovering in the phase that needs it that the
/// sign-in flow never captured it, and because an ID token that sits in
/// memory only would be gone on the next launch — the app would have a signed
/// in user and no way to prove it. The storage, and its being the *secure*
/// storage, is the part of this that is hard to retrofit.
class CredentialVault {
  const CredentialVault(this._store);

  final CredentialStore _store;

  static const String idTokenKey = 'auth.google.idToken';

  Future<String?> readIdToken() => _store.read(idTokenKey);

  /// Stores [token], or clears the stored one when [token] is null.
  ///
  /// Null is a real case: a platform can complete an authentication without
  /// returning an ID token, and keeping the previous one would leave the app
  /// holding a credential for a sign-in that has since been replaced.
  Future<void> writeIdToken(String? token) => token == null
      ? _store.delete(idTokenKey)
      : _store.write(idTokenKey, token);

  Future<void> clear() => _store.delete(idTokenKey);
}
