import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/auth_config.dart';
import '../domain/auth_user.dart';

/// One authenticated Google account, reduced to what this app uses.
class GoogleSession {
  const GoogleSession({required this.user, required this.idToken});

  final AuthUser user;

  /// The ID token, if the platform issued one.
  ///
  /// Nullable because it can be absent — on Android it requires a server
  /// client id, and a build configured through `google-services.json`
  /// without a web client entry will authenticate and return nothing. The
  /// repository stores whatever arrives rather than asserting, so a
  /// misconfiguration shows up as "no credential" in the phase that needs
  /// one instead of as a crash in the sign-in the user just completed.
  final String? idToken;
}

/// What the auth repository needs from the Google SDK.
///
/// ## Why there is an interface over a plugin that already has one
///
/// `GoogleSignIn` is a singleton with a static instance, an initialize-once
/// contract and platform channels underneath: a test cannot construct one,
/// cannot make it fail, and cannot assert that sign-out was called. Every
/// behaviour worth testing in this feature — that a cancellation is not an
/// error, that each failure code produces copy a person can act on, that
/// signing out clears the credential even when the provider call throws —
/// lives in the mapping between this and `AuthRepository`. Putting a seam
/// here is what makes that mapping testable without an emulator.
///
/// It is deliberately four methods wide. Scopes, authorization tokens,
/// server auth codes and the account-change stream are all things the plugin
/// does that this app does not need, and an interface that mirrored the whole
/// SDK would be a second SDK to maintain.
abstract interface class GoogleSignInClient {
  /// Whether this platform can show a sign-in prompt at all.
  ///
  /// False on web, where the flow has to be started from a rendered Google
  /// button rather than from code. Checked rather than assumed so the
  /// failure is a sentence on the screen instead of an exception.
  bool get canPrompt;

  /// Prepares the SDK. Safe to call repeatedly; the work happens once.
  Future<void> initialize();

  /// Shows the account picker and returns the chosen account.
  ///
  /// Throws [GoogleSignInException] for every outcome other than success,
  /// including the user dismissing the sheet.
  Future<GoogleSession> authenticate();

  /// Re-establishes the session without showing anything, if the platform
  /// can. Returns null when it cannot — which includes there being no
  /// account to restore.
  Future<GoogleSession?> restore();

  Future<void> signOut();
}

/// The real client: `google_sign_in` on the device.
class PluginGoogleSignInClient implements GoogleSignInClient {
  PluginGoogleSignInClient({required this.config, GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final AuthConfig config;
  final GoogleSignIn _signIn;

  /// The plugin's contract is that `initialize` is called exactly once and
  /// awaited before anything else.
  ///
  /// Static, because what is being initialized is a process-wide singleton:
  /// a second client — one built after a provider rebuild, say — would
  /// otherwise initialize the same `GoogleSignIn.instance` again, which the
  /// plugin documents as undefined behaviour. The consequence is that the
  /// first configuration in a process wins, which is correct here because a
  /// build has exactly one.
  ///
  /// A future rather than a boolean, so two sign-in taps in the same frame
  /// await the same initialization instead of racing two of them.
  static Future<void>? _initialization;

  @override
  bool get canPrompt => _signIn.supportsAuthenticate();

  @override
  Future<void> initialize() => _initialization ??= _signIn.initialize(
    serverClientId: config.serverClientIdOrNull,
    clientId: config.iosClientIdOrNull,
  );

  @override
  Future<GoogleSession> authenticate() async {
    await initialize();
    return _sessionFor(await _signIn.authenticate());
  }

  @override
  Future<GoogleSession?> restore() async {
    await initialize();

    // Returns a null *future*, not a null account, on platforms that cannot
    // attempt this silently — so the null check has to happen twice.
    final attempt = _signIn.attemptLightweightAuthentication();
    if (attempt == null) return null;

    final account = await attempt;
    return account == null ? null : _sessionFor(account);
  }

  @override
  Future<void> signOut() async {
    await initialize();
    await _signIn.signOut();
  }

  static GoogleSession _sessionFor(GoogleSignInAccount account) =>
      GoogleSession(
        user: AuthUser(
          id: account.id,
          displayName: displayNameFor(account.displayName, account.email),
          email: account.email,
        ),
        idToken: account.authentication.idToken,
      );

  /// A name to greet the user by.
  ///
  /// Google does not promise a display name — an account can have none —
  /// and a greeting that reads "Hello, " is worse than a guess. The local
  /// part of the email is the guess, and the user can correct it in the next
  /// step of setup, which already seeds its name field from this.
  static String displayNameFor(String? displayName, String email) {
    final given = displayName?.trim() ?? '';
    if (given.isNotEmpty) return given;

    final local = email.split('@').first.trim();
    return local.isEmpty ? email : local;
  }
}
