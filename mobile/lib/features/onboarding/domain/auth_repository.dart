import 'auth_result.dart';
import 'session_restore.dart';

/// The boundary between the onboarding UI and whatever actually signs a user
/// in.
///
/// Phase 03 shipped only a mock. Phase 12 added a Google-backed
/// implementation, and the swap cost one provider override plus one method on
/// this interface — `restoreSession`, because a real credential expires and a
/// mock one never did. No screen or controller changed behaviour, which is
/// what the interface was for.
abstract interface class AuthRepository {
  /// Runs the provider's sign-in flow.
  ///
  /// Returns rather than throws, because all three outcomes — success,
  /// cancellation and failure — are ordinary flow a screen must render. An
  /// exception would make cancellation look exceptional, which it is not.
  Future<AuthResult> signInWithGoogle();

  /// Re-establishes the provider session without showing the user anything.
  ///
  /// Called once per launch for a user who already has a session, to replace
  /// a credential that has almost certainly expired since they last had the
  /// app open. It returns what happened rather than a user, because the app
  /// already knows who is signed in — this is about the credential, not the
  /// identity — and because nothing it can return should end a session. See
  /// [SessionRestore].
  Future<SessionRestore> restoreSession();

  /// Forgets the current session.
  Future<void> signOut();
}
