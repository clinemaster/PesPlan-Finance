import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_auth_repository.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_result.dart';
import '../../domain/auth_user.dart';

/// Where sign-in actually happens.
///
/// Phase 03 binds this to [MockAuthRepository]. Phase 12 overrides it with a
/// Google-backed implementation; tests override it with a repository pinned
/// to the scenario under test. Nothing else in the feature constructs a
/// repository, so there is exactly one line to change.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

/// The outcome the mock will produce next.
///
/// Exposed as a provider so the hidden review menu on the welcome screen can
/// drive the cancellation and failure states. The repository is constructed
/// once, so the controller below records the choice and [AuthController]
/// applies it to the instance immediately before each attempt.
class MockAuthScenarioController extends Notifier<MockAuthScenario> {
  @override
  MockAuthScenario build() => MockAuthScenario.success;

  void select(MockAuthScenario scenario) => state = scenario;
}

final mockAuthScenarioProvider =
    NotifierProvider<MockAuthScenarioController, MockAuthScenario>(
      MockAuthScenarioController.new,
    );

/// What the welcome screen is currently showing.
///
/// A sealed type rather than a bag of booleans: the screen switches over it
/// exhaustively, so adding a state later forces every call site to decide
/// what it looks like instead of silently falling through to the idle case.
sealed class AuthState {
  const AuthState();
}

/// Nothing has been attempted, or the user dismissed the last message.
final class AuthIdle extends AuthState {
  const AuthIdle();

  @override
  bool operator ==(Object other) => other is AuthIdle;

  @override
  int get hashCode => (AuthIdle).hashCode;
}

/// A sign-in is in flight. The button shows a spinner and ignores taps.
final class AuthInProgress extends AuthState {
  const AuthInProgress();

  @override
  bool operator ==(Object other) => other is AuthInProgress;

  @override
  int get hashCode => (AuthInProgress).hashCode;
}

/// The user backed out of the provider sheet.
///
/// Rendered as a calm, neutral note rather than an error, because the user
/// did this on purpose and nothing went wrong.
final class AuthDismissed extends AuthState {
  const AuthDismissed();

  @override
  bool operator ==(Object other) => other is AuthDismissed;

  @override
  int get hashCode => (AuthDismissed).hashCode;
}

/// Sign-in failed. [message] is user-facing and safe to display verbatim.
final class AuthErrored extends AuthState {
  const AuthErrored(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is AuthErrored && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// Sign-in succeeded. Onboarding seeds its draft from [user].
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticated && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

/// Drives one sign-in attempt and exposes its state to the welcome screen.
///
/// The controller holds no widget references and no [BuildContext], so the
/// whole sign-in lifecycle — including the loading, cancelled and error
/// branches — is testable without pumping a frame.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthIdle();

  Future<void> signInWithGoogle() async {
    // A second tap while the first attempt is in flight would start a
    // parallel sign-in and let the later result overwrite the earlier one.
    // The button is already disabled while loading; this guards the case
    // where something else calls the method.
    if (state is AuthInProgress) return;

    state = const AuthInProgress();

    final repository = ref.read(authRepositoryProvider);

    // Keep the mock honest about which path the reviewer asked for. The real
    // repository has no scenario, so this is confined to the mock.
    if (repository is MockAuthRepository) {
      repository.scenario = ref.read(mockAuthScenarioProvider);
    }

    final result = await repository.signInWithGoogle();

    state = switch (result) {
      AuthSuccess(:final user) => AuthAuthenticated(user),
      AuthCancelled() => const AuthDismissed(),
      AuthFailed(:final message) => AuthErrored(message),
    };
  }

  /// Clears a cancellation or error note so the screen returns to its
  /// resting state — used when the user dismisses the message or retries.
  void acknowledge() {
    if (state is AuthDismissed || state is AuthErrored) {
      state = const AuthIdle();
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthIdle();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The signed-in user, or null. Convenience for widgets that only need the
/// identity and not the whole state machine.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated ? state.user : null;
});
