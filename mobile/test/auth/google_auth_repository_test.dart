import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lifepilot_finance/core/storage/credential_store.dart';
import 'package:lifepilot_finance/features/onboarding/data/credential_vault.dart';
import 'package:lifepilot_finance/features/onboarding/data/google_auth_repository.dart';
import 'package:lifepilot_finance/features/onboarding/data/google_sign_in_client.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_result.dart';
import 'package:lifepilot_finance/features/onboarding/domain/auth_user.dart';
import 'package:lifepilot_finance/features/onboarding/domain/session_restore.dart';

import 'fakes.dart';

/// The repository under test, plus the two things it talks to.
({
  GoogleAuthRepository repository,
  FakeGoogleSignInClient client,
  InMemoryCredentialStore store,
})
build({
  GoogleSession? session,
  Object? error,
  GoogleSession? restored,
  Object? restoreError,
  Object? signOutError,
  bool canPrompt = true,
  InMemoryCredentialStore? store,
}) {
  final client = FakeGoogleSignInClient(
    session: session,
    error: error,
    restored: restored,
    restoreError: restoreError,
    signOutError: signOutError,
    canPrompt: canPrompt,
  );
  final credentials = store ?? InMemoryCredentialStore();

  return (
    repository: GoogleAuthRepository(
      client: client,
      vault: CredentialVault(credentials),
    ),
    client: client,
    store: credentials,
  );
}

void main() {
  group('signing in', () {
    test('returns the account Google reported', () async {
      final subject = build();

      final result = await subject.repository.signInWithGoogle();

      expect(result, isA<AuthSuccess>());
      expect(
        (result as AuthSuccess).user,
        const AuthUser(
          id: 'google-uid-1',
          displayName: 'Amina Hassan',
          email: 'amina.hassan@gmail.com',
        ),
      );
    });

    test('keeps the ID token in secure storage', () async {
      final subject = build();

      await subject.repository.signInWithGoogle();

      expect(
        await subject.store.read(CredentialVault.idTokenKey),
        'id-token-1',
      );
    });

    test('stores nothing when the platform issued no token', () async {
      // A build configured without a web client id authenticates and returns
      // no ID token. The sign-in still succeeds — the user is who they say
      // they are — but nothing is kept, so the phase that needs a credential
      // finds none rather than finding a stale one.
      final subject = build(
        session: FakeGoogleSignInClient.sessionWith(idToken: null),
      );

      final result = await subject.repository.signInWithGoogle();

      expect(result, isA<AuthSuccess>());
      expect(await subject.store.read(CredentialVault.idTokenKey), isNull);
    });

    test('replaces a token left over from an earlier session', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialVault.idTokenKey, 'stale-token');

      await build(store: store).repository.signInWithGoogle();

      expect(await store.read(CredentialVault.idTokenKey), 'id-token-1');
    });

    test('clears a leftover token when the new sign-in has none', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialVault.idTokenKey, 'stale-token');

      await build(
        store: store,
        session: FakeGoogleSignInClient.sessionWith(idToken: null),
      ).repository.signInWithGoogle();

      expect(await store.read(CredentialVault.idTokenKey), isNull);
    });

    test('prepares the SDK before asking it anything', () async {
      // The plugin's contract: initialization completes before any other
      // call on the instance.
      final subject = build();

      await subject.repository.signInWithGoogle();

      expect(subject.client.initializeCalls, greaterThan(0));
      expect(subject.client.authenticateCalls, 1);
    });

    test('does not open a prompt the platform cannot show', () async {
      final subject = build(canPrompt: false);

      final result = await subject.repository.signInWithGoogle();

      expect(result, isA<AuthFailed>());
      expect(subject.client.authenticateCalls, 0);
    });
  });

  group('a dismissed sheet', () {
    test('is a cancellation, not a failure', () async {
      final subject = build(
        error: exceptionFor(GoogleSignInExceptionCode.canceled),
      );

      expect(await subject.repository.signInWithGoogle(), isA<AuthCancelled>());
    });

    test('leaves no credential behind', () async {
      final subject = build(
        error: exceptionFor(GoogleSignInExceptionCode.canceled),
      );

      await subject.repository.signInWithGoogle();

      expect(await subject.store.read(CredentialVault.idTokenKey), isNull);
    });
  });

  group('failures', () {
    /// Every code the plugin currently defines, except the cancellation that
    /// is deliberately not a failure.
    const codes = [
      GoogleSignInExceptionCode.unknownError,
      GoogleSignInExceptionCode.interrupted,
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError,
      GoogleSignInExceptionCode.uiUnavailable,
      GoogleSignInExceptionCode.userMismatch,
    ];

    for (final code in codes) {
      test('${code.name} reaches the screen as a sentence', () async {
        final subject = build(error: exceptionFor(code));

        final result = await subject.repository.signInWithGoogle();

        expect(result, isA<AuthFailed>());
        final message = (result as AuthFailed).message;

        // The description the SDK supplied names a client id and a Play
        // services package. None of that belongs on a welcome screen.
        expect(message, isNot(contains('serverClientId')));
        expect(message, isNot(contains('com.google.android.gms')));
        expect(message, isNot(contains(code.name)));
        expect(message.trim(), isNotEmpty);
        expect(message.endsWith('.'), isTrue);
      });
    }

    test(
      'a misconfigured build says so rather than blaming the user',
      () async {
        final subject = build(
          error: exceptionFor(
            GoogleSignInExceptionCode.clientConfigurationError,
          ),
        );

        final result = await subject.repository.signInWithGoogle();

        expect((result as AuthFailed).message, contains('build'));
      },
    );

    test('a device without Play services says that', () async {
      final subject = build(
        error: exceptionFor(
          GoogleSignInExceptionCode.providerConfigurationError,
        ),
      );

      final result = await subject.repository.signInWithGoogle();

      expect((result as AuthFailed).message, contains('Google Play services'));
    });

    test('a phone with no Google account is told what to do', () async {
      // Android has no code for this: it arrives as unknownError carrying
      // "No credential available", and the generic message would send
      // someone whose connection is fine to go and check their connection.
      final subject = build(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'No credential available: No credentials available',
        ),
      );

      final result = await subject.repository.signInWithGoogle();

      expect((result as AuthFailed).message, contains('no Google account'));
      expect(result.message, isNot(contains('connection')));
    });

    test(
      'an unrecognised description falls back to the generic copy',
      () async {
        // The string match above is a heuristic. When it misses, the user
        // still gets a sentence.
        final subject = build(
          error: const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'something else entirely',
          ),
        );

        final result = await subject.repository.signInWithGoogle();

        expect(
          (result as AuthFailed).message,
          contains('Check your connection'),
        );
      },
    );

    test('anything that is not an SDK failure still produces copy', () async {
      // A platform exception, a missing plugin, a type error in a transitive
      // dependency: the user gets a sentence either way.
      final subject = build(error: StateError('channel went away'));

      final result = await subject.repository.signInWithGoogle();

      expect(result, isA<AuthFailed>());
      expect((result as AuthFailed).message, isNot(contains('channel')));
    });
  });

  group('when the keystore refuses the credential', () {
    test('the sign-in is reported as failed', () async {
      final repository = GoogleAuthRepository(
        client: FakeGoogleSignInClient(),
        vault: CredentialVault(FailingCredentialStore()),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<AuthFailed>());
    });

    test('and the provider is signed back out', () async {
      // Otherwise Google considers this device signed in while the app holds
      // nothing, and the disagreement surfaces later as calls that cannot be
      // made.
      final client = FakeGoogleSignInClient();
      final repository = GoogleAuthRepository(
        client: client,
        vault: CredentialVault(FailingCredentialStore()),
      );

      await repository.signInWithGoogle();

      expect(client.signOutCalls, 1);
    });
  });

  group('refreshing a restored session', () {
    test('replaces the stored credential', () async {
      final subject = build(
        restored: FakeGoogleSignInClient.sessionWith(idToken: 'fresh-token'),
      );

      expect(
        await subject.repository.restoreSession(),
        SessionRestore.refreshed,
      );
      expect(
        await subject.store.read(CredentialVault.idTokenKey),
        'fresh-token',
      );
    });

    test('reports needing the user when it cannot be done silently', () async {
      final subject = build();

      expect(
        await subject.repository.restoreSession(),
        SessionRestore.needsUser,
      );
    });

    test('swallows a provider error', () async {
      // A refresh runs at launch with nothing waiting on it. Throwing here
      // would take down a start-up for a credential nothing has asked for.
      final subject = build(restoreError: StateError('offline'));

      expect(
        await subject.repository.restoreSession(),
        SessionRestore.unavailable,
      );
    });

    test('keeps the old credential when the refresh fails', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialVault.idTokenKey, 'yesterdays-token');

      await build(
        store: store,
        restoreError: StateError('offline'),
      ).repository.restoreSession();

      expect(await store.read(CredentialVault.idTokenKey), 'yesterdays-token');
    });
  });

  group('signing out', () {
    test('ends the session on both sides', () async {
      final subject = build();
      await subject.repository.signInWithGoogle();

      await subject.repository.signOut();

      expect(subject.client.signOutCalls, 1);
      expect(await subject.store.read(CredentialVault.idTokenKey), isNull);
    });

    test('clears the credential even when the provider throws', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialVault.idTokenKey, 'id-token-1');
      final subject = build(store: store, signOutError: StateError('boom'));

      await subject.repository.signOut();

      expect(await store.read(CredentialVault.idTokenKey), isNull);
    });

    test('completes even when the keystore throws', () async {
      // Someone trying to leave an account on a shared phone has to end up
      // out of it, whatever the platform says.
      final repository = GoogleAuthRepository(
        client: FakeGoogleSignInClient(),
        vault: CredentialVault(
          FailingCredentialStore(onWrite: false, onDelete: true),
        ),
      );

      await expectLater(repository.signOut(), completes);
    });
  });

  group('the name the user is greeted by', () {
    test('is the one Google supplied', () {
      expect(
        PluginGoogleSignInClient.displayNameFor('Amina Hassan', 'a@b.com'),
        'Amina Hassan',
      );
    });

    test('falls back to the email when the account has no name', () {
      // Google does not promise a display name, and "Hello, " is worse than
      // a guess the user can correct in the next step of setup.
      expect(
        PluginGoogleSignInClient.displayNameFor(null, 'amina.h@gmail.com'),
        'amina.h',
      );
      expect(
        PluginGoogleSignInClient.displayNameFor('   ', 'amina.h@gmail.com'),
        'amina.h',
      );
    });

    test('falls back to the whole address when there is no local part', () {
      expect(PluginGoogleSignInClient.displayNameFor(null, '@odd'), '@odd');
    });
  });
}
