/// What a silent attempt to re-establish the provider session found.
///
/// ## Why none of these sign the user out
///
/// An ID token lasts about an hour, so a returning user's stored credential
/// is almost always stale and worth refreshing in the background. The
/// temptation is to treat a failed refresh as "this session is over" and
/// return the user to the welcome screen. That would be wrong, because the
/// provider cannot tell this app the difference between an account that has
/// revoked access and a phone that is on a bus going through a tunnel. One
/// of those should end a session; the other happens every day. Returning
/// someone to a sign-in screen, with their own ledger behind it, because
/// their connection dropped is the worse mistake, so the local session
/// always stands and the refresh is only ever an improvement.
enum SessionRestore {
  /// The provider confirmed the account without asking the user anything,
  /// and the stored credential has been replaced with a fresh one.
  refreshed,

  /// The provider cannot answer without showing the user something. Nothing
  /// is wrong; there is simply nothing to do until they sign in again.
  needsUser,

  /// The provider could not be reached, or refused for a reason the app
  /// cannot act on. Diagnostic only.
  unavailable,
}
