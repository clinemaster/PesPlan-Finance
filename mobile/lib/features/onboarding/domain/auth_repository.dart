import 'auth_result.dart';

/// The boundary between the onboarding UI and whatever actually signs a user
/// in.
///
/// Phase 03 ships only [MockAuthRepository]. Phase 12 adds a Google-backed
/// implementation and changes one provider override; no screen, controller or
/// test above this interface should need editing for that swap. If a change in
/// Phase 12 forces a widget to change, this interface was leaking.
abstract interface class AuthRepository {
  /// Runs the provider's sign-in flow.
  ///
  /// Returns rather than throws, because all three outcomes — success,
  /// cancellation and failure — are ordinary flow a screen must render. An
  /// exception would make cancellation look exceptional, which it is not.
  Future<AuthResult> signInWithGoogle();

  /// Forgets the current session.
  Future<void> signOut();
}
