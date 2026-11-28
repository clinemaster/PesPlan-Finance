import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';
import '../domain/auth_user.dart';
import '../domain/session_restore.dart';

/// Which outcome the next sign-in attempt should produce.
///
/// Phase 03 has to show a cancellation state and an error state, and neither
/// is reachable if the mock always succeeds. Making the outcome selectable
/// lets a reviewer see all three paths, and lets a test pick one without
/// stubbing timers.
enum MockAuthScenario {
  /// Returns a signed-in user after a short delay.
  success,

  /// Returns [AuthCancelled], as if the user dismissed the provider sheet.
  cancel,

  /// Returns [AuthFailed] with a user-facing message.
  failure,
}

/// A stand-in for Google Sign-In.
///
/// It performs no network call, holds no credential and talks to no provider
/// SDK. The delay exists so the button's loading state is visible and so the
/// screens are built against a flow that genuinely takes time — a mock that
/// returns instantly hides every race the real one will have.
///
/// ## What happened when the real provider arrived
///
/// Phase 12 added `GoogleAuthRepository` beside this class and taught
/// `auth_providers.dart` to choose between them, which is what the interface
/// was for. The swap cost one method — `restoreSession`, because a real
/// credential expires and a mock one never did — and no screen changed
/// behaviour. The copy on three screens did change, but only where it would
/// otherwise have claimed a Google account that a mock build does not have.
///
/// ## Why it is still here
///
/// A build with no Google Cloud project behind it has to run: that is every
/// fresh clone, and every reviewer who wants to see the screens without
/// provisioning OAuth credentials first. It is also the only way to reach
/// the cancelled and failed states on demand, which a real provider will not
/// produce to order.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.scenario = MockAuthScenario.success,
    this.delay = const Duration(milliseconds: 1200),
  });

  /// The outcome of the next [signInWithGoogle] call.
  MockAuthScenario scenario;

  /// How long the simulated provider sheet takes. Tests pass [Duration.zero].
  final Duration delay;

  /// A plausible Tanzanian user, so screenshots and manual review show
  /// realistic content rather than "Test User".
  static const AuthUser demoUser = AuthUser(
    id: 'mock-user-001',
    displayName: 'Amina Hassan',
    email: 'amina.hassan@gmail.com',
  );

  @override
  Future<AuthResult> signInWithGoogle() async {
    await Future<void>.delayed(delay);

    return switch (scenario) {
      MockAuthScenario.success => const AuthSuccess(demoUser),
      MockAuthScenario.cancel => const AuthCancelled(),
      MockAuthScenario.failure => const AuthFailed(
        'Could not reach Google. Check your connection and try again.',
      ),
    };
  }

  /// Always [SessionRestore.needsUser].
  ///
  /// The honest answer: this provider issued no credential, so there is
  /// nothing to refresh and nothing it could confirm. Deliberately not
  /// `refreshed`, which would be claiming to have revalidated a session it
  /// never held in the first place.
  @override
  Future<SessionRestore> restoreSession() async => SessionRestore.needsUser;

  @override
  Future<void> signOut() async {
    // Nothing is persisted, so there is nothing to clear.
    // `GoogleAuthRepository` deletes the stored credential here.
  }
}
