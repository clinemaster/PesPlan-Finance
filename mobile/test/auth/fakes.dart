import 'package:google_sign_in/google_sign_in.dart';
import 'package:lifepilot_finance/core/storage/credential_store.dart';
import 'package:lifepilot_finance/features/onboarding/data/google_sign_in_client.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_result.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_user.dart';
import 'package:lifepilot_finance/features/onboarding/domain/session_restore.dart';

/// A Google client that returns whatever the test asked for.
///
/// This is the whole reason `GoogleSignInClient` exists: `GoogleSignIn` is a
/// static singleton over platform channels, so without a seam here none of
/// the mapping in `GoogleAuthRepository` — which is where the decisions are —
/// could be tested at all.
class FakeGoogleSignInClient implements GoogleSignInClient {
  FakeGoogleSignInClient({
    this.session,
    this.error,
    this.restored,
    this.restoreError,
    this.signOutError,
    this.canPrompt = true,
  });

  /// Returned by [authenticate] unless [error] is set.
  GoogleSession? session;

  /// Thrown by [authenticate].
  Object? error;

  /// Returned by [restore].
  GoogleSession? restored;

  Object? restoreError;
  Object? signOutError;

  @override
  bool canPrompt;

  int initializeCalls = 0;
  int authenticateCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;

  static const AuthUser user = AuthUser(
    id: 'google-uid-1',
    displayName: 'Amina Hassan',
    email: 'amina.hassan@gmail.com',
  );

  static GoogleSession sessionWith({String? idToken = 'id-token-1'}) =>
      GoogleSession(user: user, idToken: idToken);

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<GoogleSession> authenticate() async {
    authenticateCalls++;
    if (error != null) throw error!;
    return session ?? sessionWith();
  }

  @override
  Future<GoogleSession?> restore() async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
    return restored;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }
}

/// A credential store whose writes or deletes fail, as the keystore can.
class FailingCredentialStore implements CredentialStore {
  FailingCredentialStore({this.onWrite = true, this.onDelete = false});

  final bool onWrite;
  final bool onDelete;

  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (onWrite) {
      throw const CredentialStoreFailure('write', 'keystore unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (onDelete) {
      throw const CredentialStoreFailure('delete', 'keystore unavailable');
    }
    values.remove(key);
  }
}

/// An [AuthRepository] that records what it was asked to do.
///
/// Used for the launch refresh, which is about whether the controller calls
/// the repository at the right moment rather than about what Google says.
class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({this.restore = SessionRestore.refreshed});

  final SessionRestore restore;

  int signInCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthResult> signInWithGoogle() async {
    signInCalls++;
    return const AuthSuccess(FakeGoogleSignInClient.user);
  }

  @override
  Future<SessionRestore> restoreSession() async {
    restoreCalls++;
    return restore;
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

/// A [GoogleSignInException] for [code], as the plugin would raise it.
GoogleSignInException exceptionFor(GoogleSignInExceptionCode code) =>
    GoogleSignInException(
      code: code,
      description:
          'serverClientId 000-test.apps.googleusercontent.com '
          'rejected by com.google.android.gms',
    );
