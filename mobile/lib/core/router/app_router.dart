import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/home/presentation/screens/home_placeholder_screen.dart';
import '../../features/onboarding/presentation/providers/auth_providers.dart';
import '../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/completion_screen.dart';
import '../../features/onboarding/presentation/screens/preferences_setup_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../showcase/design_system_showcase.dart';
import 'routes.dart';

/// The app's router, with the session guard that decides which section a
/// user belongs in.
///
/// ## Why the guard lives here and not in the screens
///
/// Three screens each calling `context.go` after checking their own
/// conditions is three places to get the rule wrong, and the bug it produces
/// — a user landing in onboarding with no draft, or back on welcome while
/// signed in — only shows up on a specific path through the app. One
/// `redirect` means the rule is stated once and applies to every entry,
/// including deep links and the back button.
///
/// Because of this, screens do not navigate forward after completing a step
/// where the guard already implies the destination. Signing in makes the
/// router move to onboarding; completing onboarding makes it move to home.
/// The screens change state, the router responds.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router needs a Listenable to know when to re-run the guard. Bridging
  // Riverpod to it with a counter is the smallest thing that works: the value
  // is never read, only its change.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, _) => refresh.value++)
    ..listen(onboardingControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read the controllers themselves, never a provider derived from
      // them. This guard runs synchronously from the listeners above, at a
      // point where a derived provider has been marked dirty but not yet
      // recomputed — so `currentUserProvider` would still report the
      // previous user and send a signed-out person back into onboarding.
      // The controllers are the values that just changed, so they are
      // current by definition.
      final signedIn = ref.read(authControllerProvider) is AuthAuthenticated;
      final onboarding = ref.read(onboardingControllerProvider);
      final location = state.matchedLocation;

      // The showcase is a review tool, not part of the product flow.
      if (location == Routes.showcase) return null;

      if (!signedIn) {
        return location == Routes.welcome ? null : Routes.welcome;
      }

      if (!onboarding.completed) {
        return location.startsWith(Routes.onboardingPrefix)
            ? null
            : Routes.onboardingProfile;
      }

      // Onboarding is done: welcome and the onboarding steps are behind them.
      return location.startsWith(Routes.onboardingPrefix) ||
              location == Routes.welcome
          ? Routes.home
          : null;
    },
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.onboardingProfile,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: Routes.onboardingPreferences,
        builder: (context, state) => const PreferencesSetupScreen(),
      ),
      GoRoute(
        path: Routes.onboardingComplete,
        builder: (context, state) => const CompletionScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
      GoRoute(
        path: Routes.showcase,
        builder: (context, state) => const ShowcaseHome(),
      ),
    ],
  );
});
