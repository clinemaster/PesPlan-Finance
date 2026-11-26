import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../domain/app_language.dart';
import '../../domain/country.dart';
import '../../domain/profile_validator.dart';
import '../../domain/user_profile.dart';
import 'auth_providers.dart';

/// The onboarding draft plus whether the user has finished.
///
/// [draft] is null until sign-in produces an identity to seed it from, which
/// is also what the router uses to keep someone out of the profile screens
/// before they have signed in.
class OnboardingState {
  const OnboardingState({this.draft, this.completed = false});

  final UserProfile? draft;

  /// Set once the user taps through the completion screen. The router sends
  /// them to the app from then on instead of back into onboarding.
  final bool completed;

  bool get hasDraft => draft != null;

  /// Whether the profile step has everything it needs to advance.
  bool get canContinueFromProfile {
    final current = draft;
    if (current == null) return false;
    return ProfileValidator.canSubmitProfile(
      name: current.name,
      phone: current.phone,
    );
  }

  OnboardingState copyWith({UserProfile? draft, bool? completed}) =>
      OnboardingState(
        draft: draft ?? this.draft,
        completed: completed ?? this.completed,
      );

  @override
  bool operator ==(Object other) =>
      other is OnboardingState &&
      other.draft == draft &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(draft, completed);
}

/// Holds the answers as the user moves through onboarding.
///
/// Every mutation replaces the whole draft rather than editing fields in
/// place, so going back a screen cannot leave a half-applied change behind,
/// and each transition is a value a test can assert on.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Seeding from auth rather than having the welcome screen push the user
    // across keeps the dependency pointing one way: onboarding knows about
    // auth, auth knows nothing about onboarding.
    //
    // This re-runs only when the auth state actually changes value, which is
    // why AuthState implements ==. Without it, an identical rebuild would
    // discard a half-filled draft.
    final auth = ref.watch(authControllerProvider);

    if (auth is AuthAuthenticated) {
      return OnboardingState(draft: UserProfile.fromAuthUser(auth.user));
    }
    return const OnboardingState();
  }

  void updateName(String value) => _edit((draft) => draft.copyWith(name: value));

  /// Empty input clears the field rather than storing `''`, so "skipped" has
  /// one representation instead of two.
  void updatePhone(String value) => _edit(
    (draft) => value.trim().isEmpty
        ? draft.copyWith(clearPhone: true)
        : draft.copyWith(phone: value),
  );

  /// Explicit skip, for the button that says so.
  void clearPhone() => _edit((draft) => draft.copyWith(clearPhone: true));

  /// Choosing a country also moves the currency to that country's own.
  ///
  /// It is the answer the user almost always wants, and leaving TZS selected
  /// after someone picks Germany is a quiet way to get the wrong currency
  /// into an account. The currency field stays editable underneath, so the
  /// minority case is one tap away rather than impossible.
  void updateCountry(Country value) => _edit(
    (draft) => draft.copyWith(country: value, currency: value.currency),
  );

  void updateCurrency(Currency value) =>
      _edit((draft) => draft.copyWith(currency: value));

  void updateLanguage(AppLanguage value) =>
      _edit((draft) => draft.copyWith(language: value));

  /// Marks onboarding finished. Refuses while the draft is incomplete so the
  /// router cannot be pushed past a form that has not been filled in.
  void complete() {
    if (!state.canContinueFromProfile) return;
    state = state.copyWith(completed: true);
  }

  /// Drops everything. Used when a user signs out or cancels the flow.
  void reset() => state = const OnboardingState();

  void _edit(UserProfile Function(UserProfile draft) change) {
    final current = state.draft;
    if (current == null) return;
    state = state.copyWith(draft: change(current));
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
