import 'auth_user.dart';

/// The outcome of one sign-in attempt.
///
/// Cancellation is a separate case rather than an error with a special
/// message. A user who backs out of the Google sheet has not hit a problem,
/// and showing them a red failure for a deliberate choice is both wrong and
/// alarming. Keeping the two apart in the type means a screen cannot
/// accidentally conflate them — the switch will not compile until both are
/// handled.
sealed class AuthResult {
  const AuthResult();
}

/// Sign-in completed and produced an identity.
final class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);

  final AuthUser user;
}

/// The user dismissed the provider's sheet. Not an error.
final class AuthCancelled extends AuthResult {
  const AuthCancelled();
}

/// Sign-in failed for a reason the user may be able to act on.
///
/// [message] is user-facing, so it must stay free of provider jargon and
/// stack detail — it goes straight onto the screen.
final class AuthFailed extends AuthResult {
  const AuthFailed(this.message);

  final String message;
}
