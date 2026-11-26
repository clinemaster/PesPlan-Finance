/// Every route path in the app, in one place.
///
/// String literals scattered across screens drift: one gets renamed, a
/// `context.go` elsewhere keeps the old spelling, and the failure is a blank
/// screen at runtime rather than a compile error. Constants make a rename a
/// single edit.
abstract final class Routes {
  /// Sign-in. The entry point for anyone without a session.
  static const String welcome = '/welcome';

  /// Step 1 — name, email, optional phone.
  static const String onboardingProfile = '/onboarding/profile';

  /// Step 2 — country, currency, language.
  static const String onboardingPreferences = '/onboarding/preferences';

  /// Step 3 — confirmation before entering the app.
  static const String onboardingComplete = '/onboarding/complete';

  /// Prefix guard for the whole onboarding section.
  static const String onboardingPrefix = '/onboarding';

  /// The main application. A placeholder until Phase 04.
  static const String home = '/home';

  /// The Phase 02 design system showcase.
  ///
  /// Kept reachable so the visual language stays reviewable now that it is no
  /// longer what `main.dart` launches. It sits outside the session guard
  /// because reviewing components should not require signing in.
  static const String showcase = '/showcase';
}
