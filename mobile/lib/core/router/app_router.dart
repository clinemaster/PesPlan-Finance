import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/budgets/domain/budget.dart';
import '../../features/budgets/presentation/screens/budget_edit_screen.dart';
import '../../features/budgets/presentation/screens/budget_form_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/savings/domain/goal_movement.dart';
import '../../features/savings/presentation/screens/goal_detail_screen.dart';
import '../../features/savings/presentation/screens/goal_edit_screen.dart';
import '../../features/savings/presentation/screens/goal_form_screen.dart';
import '../../features/savings/presentation/screens/goal_movement_screen.dart';
import '../../features/savings/presentation/screens/goals_screen.dart';
import '../../features/onboarding/presentation/providers/auth_providers.dart';
import '../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/completion_screen.dart';
import '../../features/onboarding/presentation/screens/preferences_setup_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/placeholders/presentation/placeholder_screen.dart';
import '../../features/reports/presentation/screens/annual_report_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/reports/presentation/screens/year_comparison_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/presentation/screens/transaction_edit_screen.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../showcase/design_system_showcase.dart';
import '../design_system/tokens/app_icons.dart';
import 'routes.dart';

/// The app's router, with the session guard that decides which section a
/// user belongs in.
///
/// ## Why the guard lives here and not in the screens
///
/// Several screens each calling `context.go` after checking their own
/// conditions is several places to get the rule wrong, and the bug it
/// produces — a user landing in onboarding with no draft, or back on
/// welcome while signed in — only shows up on a specific path through the
/// app. One `redirect` means the rule is stated once and applies to every
/// entry, including deep links and the back button.
///
/// ## Why the five tabs are a StatefulShellRoute
///
/// Each branch keeps its own navigation stack, so opening something in
/// Activity, switching to Budgets and coming back leaves Activity where it
/// was. A single shared Navigator cannot do that, and the alternative —
/// rebuilding each tab from its root on every switch — loses scroll
/// position and any half-finished work on the screen.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router needs a Listenable to know when to re-run the guard. Bridging
  // Riverpod to it with a counter is the smallest thing that works: the
  // value is never read, only its change.
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
      // previous user and send a signed-out person back into the app.
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

      // Onboarding is done: welcome and the onboarding steps are behind
      // them. Everything else — the five tabs, settings, quick actions —
      // is theirs to navigate.
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

      // ------------------------------------------------- the app, in tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budgets,
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.goals,
                builder: (context, state) => const GoalsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.assistant,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Assistant',
                  icon: AppIcons.assistant,
                  message:
                      'Ask about your spending in plain language. Coming in '
                      'a later phase.',
                ),
              ),
            ],
          ),
        ],
      ),

      // -------------------------------------------- pushed over the shell
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // Over the shell, not inside the Activity branch: a form wants the
      // whole screen and a keyboard, and the bottom bar under it is only
      // somewhere to lose a tap.
      GoRoute(
        path: Routes.transactionNew,
        builder: (context, state) => TransactionFormScreen(
          initialType: switch (state.uri.queryParameters['type']) {
            'income' => TransactionType.income,
            'expense' => TransactionType.expense,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: Routes.transactionEditPattern,
        builder: (context, state) =>
            TransactionEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.budgetNew,
        builder: (context, state) => BudgetFormScreen(
          initialKind: switch (state.uri.queryParameters['kind']) {
            'overall' => BudgetKind.overall,
            'category' => BudgetKind.category,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: Routes.budgetEditPattern,
        builder: (context, state) =>
            BudgetEditScreen(id: state.pathParameters['id']!),
      ),
      // Declared before the `:id` route below, which would otherwise
      // match `/goals/new` and open a detail screen for a goal called
      // "new".
      GoRoute(
        path: Routes.goalNew,
        builder: (context, state) => const GoalFormScreen(),
      ),
      GoRoute(
        path: Routes.goalEditPattern,
        builder: (context, state) =>
            GoalEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.goalContributePattern,
        builder: (context, state) => GoalMovementScreen(
          goalId: state.pathParameters['id']!,
          kind: MovementKind.contribution,
        ),
      ),
      GoRoute(
        path: Routes.goalWithdrawPattern,
        builder: (context, state) => GoalMovementScreen(
          goalId: state.pathParameters['id']!,
          kind: MovementKind.withdrawal,
        ),
      ),
      GoRoute(
        path: Routes.goalDetailPattern,
        builder: (context, state) =>
            GoalDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: Routes.reportsAnnual,
        builder: (context, state) => const AnnualReportScreen(),
      ),
      GoRoute(
        path: Routes.reportsCompare,
        builder: (context, state) => const YearComparisonScreen(),
      ),
      GoRoute(
        path: Routes.addVoice,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Record by voice',
          icon: AppIcons.voice,
          showBack: true,
          message:
              'Say "two thousand for a bajaji" and have it filed correctly. '
              'No microphone is used in this phase.',
        ),
      ),

      GoRoute(
        path: Routes.showcase,
        builder: (context, state) => const ShowcaseHome(),
      ),
    ],
  );
});
