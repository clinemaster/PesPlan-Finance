import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';
import '../domain/auth_user.dart';

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
/// ## Why this is the only file that should change in Phase 12
///
/// Everything above it depends on [AuthRepository], not on this class. When
/// the real provider arrives it implements the same interface and the
/// provider override in `auth_providers.dart` points at it instead. If that
/// swap turns out to require edits to a screen or a controller, the
/// abstraction failed and the fix belongs here, not there.
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

  @override
  Future<void> signOut() async {
    // Nothing is persisted, so there is nothing to clear. The real
    // implementation deletes the stored token here.
  }
}
