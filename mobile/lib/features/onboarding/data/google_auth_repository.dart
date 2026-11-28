import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/storage/credential_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';
import '../domain/session_restore.dart';
import 'credential_vault.dart';
import 'google_sign_in_client.dart';

/// Signs in with Google, for real.
///
/// ## What this class is actually for
///
/// Not the sign-in itself — the plugin does that in four lines. This exists
/// to turn everything the SDK can do to you into the three outcomes the
/// welcome screen knows how to render, and to put the credential somewhere
/// defensible on the way through. Those are the two jobs, and both of them
/// are decisions rather than plumbing:
///
/// * **A cancellation is not a failure.** Google reports a dismissed sheet as
///   an exception with a code, alongside genuine errors. Showing a user who
///   changed their mind the same red banner as a network failure tells them
///   they broke something. So `canceled` becomes [AuthCancelled], which the
///   screen renders as a calm note, and everything else becomes
///   [AuthFailed] with a sentence that says what to try.
/// * **No SDK language reaches the screen.** A provider description naming a
///   client id or an activity is for a log, not for someone standing in a
///   shop trying to record what they just spent.
///
/// ## What it does not do
///
/// Verify the token. An ID token is a signed claim and this app is in no
/// position to check a signature or an audience — that belongs to the
/// backend that will accept it, which does not exist yet. The app's job is
/// to obtain the thing and keep it safe; believing it is the server's.
class GoogleAuthRepository implements AuthRepository {
  GoogleAuthRepository({required this.client, required this.vault});

  final GoogleSignInClient client;
  final CredentialVault vault;

  /// Shown when there is nothing more specific to say. Deliberately offers
  /// the one action that sometimes helps and does not speculate about why.
  static const String _genericFailure =
      'Could not sign in with Google. Check your connection and try again.';

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Before anything else, including the capability check: the plugin's
      // contract is that initialization completes before any other call,
      // and a configuration problem surfaces here as an exception the
      // mapping below already knows how to phrase.
      await client.initialize();

      if (!client.canPrompt) {
        return const AuthFailed(
          'Google sign-in cannot open on this device. Please try the '
          'Android app on a phone with Google Play services.',
        );
      }

      final session = await client.authenticate();
      await vault.writeIdToken(session.idToken);
      return AuthSuccess(session.user);
    } on GoogleSignInException catch (exception) {
      return _resultFor(exception);
    } on CredentialStoreFailure catch (failure) {
      debugPrint('Sign-in abandoned: $failure');

      // Google now considers this device signed in and this app cannot keep
      // the credential it was issued. Reporting success would leave the two
      // sides disagreeing, and the disagreement would surface later as calls
      // that cannot be made. Undo the provider's side and ask for a retry.
      await _signOutQuietly();

      return const AuthFailed(
        'Signed in with Google, but this phone could not store the sign-in '
        'securely. Please try again.',
      );
    } on Object catch (error, stack) {
      // A platform exception, a missing plugin, anything unforeseen. The
      // user gets one sentence; the detail goes to the log.
      debugPrint('Unexpected sign-in error: $error\n$stack');
      return const AuthFailed(_genericFailure);
    }
  }

  @override
  Future<SessionRestore> restoreSession() async {
    try {
      final session = await client.restore();
      if (session == null) return SessionRestore.needsUser;

      await vault.writeIdToken(session.idToken);
      return SessionRestore.refreshed;
    } on Object catch (error) {
      debugPrint('Could not refresh the Google session: $error');
      return SessionRestore.unavailable;
    }
  }

  /// Ends the session on both sides.
  ///
  /// Neither half is allowed to prevent the other. A user who taps sign out
  /// has to end up signed out even if the provider call throws and even if
  /// the keystore refuses, because the alternative is someone stuck in an
  /// account they are trying to leave — on a shared phone, with their own
  /// figures on screen.
  @override
  Future<void> signOut() async {
    await _signOutQuietly();

    try {
      await vault.clear();
    } on Object catch (error) {
      debugPrint('Could not clear the stored credential: $error');
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await client.signOut();
    } on Object catch (error) {
      debugPrint('Provider sign-out failed: $error');
    }
  }

  /// Turns one SDK failure into one thing a person can read.
  ///
  /// The switch has a default arm on purpose: the plugin documents that new
  /// codes are not a breaking change, so an exhaustive match here would turn
  /// a routine dependency bump into a compile error, and — worse — would
  /// invite handling a future code by guessing.
  static AuthResult _resultFor(GoogleSignInException exception) {
    debugPrint('Google sign-in: $exception');

    // A phone with no Google account at all reaches us as `unknownError`
    // carrying "No credential available" — the platform has no code for it,
    // and the generic message below would tell someone whose connection is
    // fine to go and check their connection. Matching an SDK string is a
    // heuristic and is treated as one: if the wording ever changes, this
    // falls through to the generic message rather than breaking.
    final description = exception.description?.toLowerCase() ?? '';
    if (exception.code == GoogleSignInExceptionCode.unknownError &&
        description.contains('no credential')) {
      return const AuthFailed(
        'There is no Google account on this phone yet. Add one in the '
        'phone settings, then try again.',
      );
    }

    return switch (exception.code) {
      // Note: Android's Credential Manager also reports some configuration
      // problems as a cancellation, and the plugin cannot tell them apart.
      // A sign-in that "cancels" itself without the user touching anything
      // is the signature of that, and the log line above is where to look.
      GoogleSignInExceptionCode.canceled => const AuthCancelled(),

      GoogleSignInExceptionCode.interrupted => const AuthFailed(
        'Sign-in stopped before it finished. Please try again.',
      ),

      GoogleSignInExceptionCode.uiUnavailable => const AuthFailed(
        'Google could not open its sign-in screen. Please try again.',
      ),

      GoogleSignInExceptionCode.clientConfigurationError => const AuthFailed(
        'This build of LifePilot is missing its Google sign-in setup, so '
        'signing in cannot work yet. Nothing on this screen will fix it.',
      ),

      GoogleSignInExceptionCode.providerConfigurationError => const AuthFailed(
        'Google sign-in is unavailable on this device. It needs an up to '
        'date Google Play services.',
      ),

      GoogleSignInExceptionCode.userMismatch => const AuthFailed(
        'That is a different Google account from the one in use. Sign out '
        'first, then sign in with the account you want.',
      ),

      _ => const AuthFailed(_genericFailure),
    };
  }
}
