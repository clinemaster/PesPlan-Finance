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

  // --------------------------------------------------- the app's five tabs
  //
  // Each is a branch of the navigation shell, so switching tabs preserves
  // where the user was in the one they left.

  /// Tab 1 — the dashboard.
  static const String home = '/home';

  /// Tab 2 — full transaction history. Placeholder until Phase 05.
  static const String transactions = '/transactions';

  /// Tab 3 — budgets. Placeholder until its phase.
  static const String budgets = '/budgets';

  /// Tab 4 — savings goals. Placeholder until its phase.
  static const String goals = '/goals';

  /// Tab 5 — the assistant. Placeholder until its phase.
  static const String assistant = '/assistant';

  // ------------------------------------------------- pushed over the shell
  //
  // These cover the bottom bar rather than living beside it: they are
  // errands, not destinations, and a user finishing one expects to land back
  // where they started.

  /// Profile and settings, reached from the dashboard header.
  static const String settings = '/settings';

  /// Recording a transaction. Full screen, over the shell: the form wants
  /// the whole display and a keyboard, and a bottom bar underneath it is
  /// just somewhere to lose a tap.
  static const String transactionNew = '/transactions/new';

  /// `?type=income` or `?type=expense` preselects the side of the ledger,
  /// so the dashboard's two quick actions land on a form that already
  /// knows which one the user pressed.
  static String transactionNewOfType(String type) =>
      '$transactionNew?type=$type';

  /// Editing an existing one. `:id` is the transaction's reference.
  static const String transactionEditPattern = '/transactions/:id/edit';

  static String transactionEdit(String id) => '/transactions/$id/edit';

  /// Speaking an amount instead of typing it. Still a placeholder.
  static const String addVoice = '/add/voice';

  /// The Phase 02 design system showcase.
  ///
  /// Kept reachable so the visual language stays reviewable now that it is no
  /// longer what `main.dart` launches. It sits outside the session guard
  /// because reviewing components should not require signing in.
  static const String showcase = '/showcase';
}
