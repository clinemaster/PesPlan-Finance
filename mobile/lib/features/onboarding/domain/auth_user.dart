/// The identity returned by a completed sign-in.
///
/// Deliberately small: an id, a display name, an email and nothing else. The
/// mock provider in Phase 03 and the real Google provider in Phase 12 can both
/// produce exactly this, so nothing above this type has to change when the
/// implementation is swapped.
///
/// There is no token field on purpose. A credential belongs in secure storage
/// behind the repository, never on a model that widgets can read.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
  });

  /// Stable provider-side identifier. Opaque to the UI.
  final String id;

  /// The name the provider knows the user by. The onboarding form seeds its
  /// name field from this, and the user may change it — what they type wins.
  final String displayName;

  /// The provider's verified email. Read-only throughout onboarding: the user
  /// did not type it and cannot correct it here, so presenting it as editable
  /// would promise something the flow cannot keep.
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.displayName == displayName &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, displayName, email);

  @override
  String toString() => 'AuthUser($id, $displayName, $email)';
}
