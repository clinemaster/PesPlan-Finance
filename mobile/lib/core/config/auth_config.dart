/// Which identity provider this build signs in with, and the identifiers it
/// needs to do it.
///
/// ## Why this is build configuration and not a setting
///
/// An OAuth client identifier is not a secret, but it is per-project and
/// per-signing-key: the identifier that works on a developer's debug build
/// is not the one a release build needs. Hard-coding one in the source would
/// mean every person building the app shares a Google Cloud project, and
/// would make the repository useless to anyone who does not have access to
/// that project. So it comes in at build time:
///
/// ```
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<the web client id>
/// ```
///
/// `docs/GOOGLE_SIGN_IN_SETUP.md` has the console steps that produce it.
///
/// ## Why a build with no identifier still runs
///
/// Most work on this app — every screen above the sign-in button — does not
/// need a real Google account, and a clone that cannot start until someone
/// provisions OAuth credentials is a clone nobody can look at. With no
/// identifier configured the app falls back to [SignInProvider.mock] and
/// says so on the welcome screen, which is the same stand-in Phases 03 to 11
/// were built against. What it must never do is pretend: a mock build is
/// labelled as one everywhere it would otherwise imply a Google account.
library;

/// Where a sign-in actually goes.
enum SignInProvider {
  /// The local stand-in. Contacts nothing, issues no credential.
  mock,

  /// Google, through the `google_sign_in` plugin.
  google,
}

class AuthConfig {
  const AuthConfig({
    this.serverClientId = '',
    this.iosClientId = '',
    this.requested = '',
  });

  /// The values this binary was compiled with.
  ///
  /// `String.fromEnvironment` resolves at compile time, which is what makes
  /// [isGoogleConfigured] a compile-time constant and lets the tree shaker
  /// see which branch a release build takes.
  static const AuthConfig fromEnvironment = AuthConfig(
    serverClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    iosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    requested: String.fromEnvironment('SIGN_IN_PROVIDER'),
  );

  /// The *web* OAuth client id of the Google Cloud project.
  ///
  /// Web, despite this being an Android app: Android's Credential Manager
  /// asks Google for an ID token addressed to a server, and the audience of
  /// that token is the web client. The Android OAuth client still has to
  /// exist — it is what ties the package name and signing fingerprint to the
  /// project — but its identifier is never named in Dart.
  final String serverClientId;

  /// The iOS OAuth client id. Unused until there is an iOS build; carried
  /// here so the one place that reads configuration stays the one place.
  final String iosClientId;

  /// An explicit `--dart-define=SIGN_IN_PROVIDER=mock|google`.
  ///
  /// Two uses. `mock` keeps the stand-in on a machine that does have
  /// credentials, which is how the cancelled and failed states stay
  /// reviewable. `google` forces the real provider when the identifiers come
  /// from `google-services.json` instead of from here, which is the other
  /// way Android supports configuring this.
  final String requested;

  bool get hasServerClientId => serverClientId.isNotEmpty;

  /// Which provider this build uses.
  ///
  /// An explicit request wins; otherwise the presence of an identifier
  /// decides. The default is the mock, because the default is a clone with
  /// no Google project behind it.
  SignInProvider get provider => switch (requested) {
    'google' => SignInProvider.google,
    'mock' => SignInProvider.mock,
    _ => hasServerClientId ? SignInProvider.google : SignInProvider.mock,
  };

  bool get isGoogleConfigured => provider == SignInProvider.google;

  bool get isMock => provider == SignInProvider.mock;

  /// Null rather than empty for the plugin, which treats null as "take it
  /// from the platform's own configuration file" and an empty string as a
  /// client id that happens to be empty.
  String? get serverClientIdOrNull => hasServerClientId ? serverClientId : null;

  String? get iosClientIdOrNull => iosClientId.isEmpty ? null : iosClientId;
}
