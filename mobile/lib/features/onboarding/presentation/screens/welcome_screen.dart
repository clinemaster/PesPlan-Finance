import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../data/mock_auth_repository.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/google_sign_in_button.dart';

/// The first screen anyone sees.
///
/// One job: say what the app is in a breath and offer a single way in.
/// Everything competing with that — a feature list, screenshots, a second
/// sign-in option — is left out, because the fastest onboarding is the one
/// with the fewest decisions in front of it.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const String tagline = 'Your money, made simple.';
  static const String intro =
      'Take control of your money with a simple way to track spending, '
      'manage budgets and reach your savings goals.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final config = ref.watch(authConfigProvider);
    final finance = context.finance;

    return Scaffold(
      body: SafeArea(
        // ## Why a screen this short scrolls
        //
        // It does not, on any ordinary phone: the spacers absorb the slack
        // and nothing moves. But this is a fixed column with no room to
        // give, and on the smallest supported screen at a large text scale
        // the brand, the promise, the button and the terms the user is being
        // asked to agree to add up to more than the viewport. Clipping any
        // of that is unacceptable — one of them is the only way into the app
        // and another is a legal notice — so the column keeps its proportions
        // while there is space and becomes scrollable when there is not.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      // The review menu is a mock affordance, so it
                      // exists only while the mock does. On a build wired
                      // to Google there is nothing to choose: the provider
                      // decides what happens.
                      _Brand(
                        onLongPress: config.isMock
                            ? () => _openReviewMenu(context, ref)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        tagline,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleSection.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        intro,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: finance.textSecondary,
                        ),
                      ),
                      const Spacer(flex: 3),

                      // The note sits directly above the button that
                      // produced it, so cause and message are never
                      // separated by the fold.
                      _AuthNote(state: authState),

                      GoogleSignInButton(
                        isLoading: authState is AuthInProgress,
                        onPressed: authState is AuthInProgress
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                      ),
                      if (config.isMock) ...[
                        const SizedBox(height: AppSpacing.md),
                        const _DemoProviderNote(),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _LegalLinks(isMock: config.isMock),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A hidden menu for choosing which outcome the mock produces next.
  ///
  /// Phase 03 has to demonstrate the cancelled and failed states, and neither
  /// is reachable while the mock always succeeds. A long-press on the brand
  /// mark is the conventional place for a review affordance: no user finds it
  /// by accident, and it adds no control to a screen whose whole point is
  /// having exactly one.
  ///
  /// It is shown only on a build that is actually using the mock.
  Future<void> _openReviewMenu(BuildContext context, WidgetRef ref) async {
    final current = ref.read(mockAuthScenarioProvider);

    final chosen = await AppBottomSheet.show<MockAuthScenario>(
      context,
      title: 'Mock sign-in outcome',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review only. Chooses what the mock provider returns next. '
            'No Google service is contacted in this phase.',
            style: AppTypography.bodySmall.copyWith(
              color: context.finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final scenario in MockAuthScenario.values)
            _ScenarioOption(
              scenario: scenario,
              isSelected: scenario == current,
              onTap: () => Navigator.of(context).pop(scenario),
            ),
        ],
      ),
    );

    if (chosen != null) {
      ref.read(mockAuthScenarioProvider.notifier).select(chosen);
    }
  }
}

class _ScenarioOption extends StatelessWidget {
  const _ScenarioOption({
    required this.scenario,
    required this.isSelected,
    required this.onTap,
  });

  final MockAuthScenario scenario;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final label = switch (scenario) {
      MockAuthScenario.success => 'Succeed',
      MockAuthScenario.cancel => 'Cancel',
      MockAuthScenario.failure => 'Fail',
    };

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  AppIcons.check,
                  size: AppIconSize.md,
                  color: context.colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: onLongPress,
          child: const BrandMark(size: 88),
        ),
        const SizedBox(height: AppSpacing.xl),
        const BrandWordmark(),
      ],
    );
  }
}

/// The cancelled and failed messages.
///
/// Two different tones, on purpose. A cancellation is the user's own choice,
/// so it gets a quiet neutral note; a failure is something that went wrong
/// and may need another attempt, so it gets the error treatment. Giving both
/// the same red banner would tell someone who simply changed their mind that
/// they had broken something.
class _AuthNote extends StatelessWidget {
  const _AuthNote({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final (message, background, foreground, icon) = switch (state) {
      AuthDismissed() => (
        'Sign-in cancelled. Tap below whenever you are ready.',
        finance.infoSurface,
        finance.infoText,
        AppIcons.info,
      ),
      AuthErrored(:final message) => (
        message,
        finance.expenseSurface,
        finance.expenseText,
        AppIcons.error,
      ),
      _ => (null, null, null, null),
    };

    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      alignment: Alignment.bottomCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: AppRadius.cardAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: AppIconSize.sm, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: AppTypography.bodySmall.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Says that this build's sign-in is not real.
///
/// ## Why this is on the screen and not only in the README
///
/// The button above it carries Google's name and mark. Someone tapping it
/// reasonably believes they are handing over a Google account, and on a mock
/// build they are not — the app invents a person and signs them in. A
/// reviewer who does not know that will report that sign-in works, and a
/// tester will wonder why their own email never appears. It is one sentence,
/// and it disappears the moment the build has real credentials.
class _DemoProviderNote extends StatelessWidget {
  const _DemoProviderNote();

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.info, size: AppIconSize.sm, color: finance.textTertiary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'Demo sign-in: no Google account is contacted and the details '
            'are invented.',
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Terms and privacy.
///
/// Both open a short in-app note rather than a browser: there is no hosted
/// policy to link to yet, and a link that opens a 404 is worse than one that
/// says plainly where the document is in the schedule.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.isMock});

  /// Changes one sentence of the privacy note. The version that says no
  /// Google service is contacted is true of a mock build and a lie on a real
  /// one, and a privacy policy is the last place to leave a stale claim.
  final bool isMock;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final linkStyle = AppTypography.caption.copyWith(
      color: context.colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.primary,
    );

    return Column(
      children: [
        Text(
          'By continuing you agree to our',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        // A Wrap, not a Row: at a large text scale, or on a narrow
        // phone, the two links plus their separator are wider than the
        // screen. Wrapping drops "Privacy Policy" to its own line, where
        // a Row clips it and the user loses a link they are being asked
        // to agree to.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LegalLink(
              label: 'Terms of Service',
              style: linkStyle,
              onTap: () => AppDialog.info(
                context,
                title: 'Terms of Service',
                message:
                    'The full terms will be published before launch. '
                    'LifePilot Finance is in development and this build '
                    'stores nothing on a server.',
              ),
            ),
            Text(
              '  ·  ',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
            _LegalLink(
              label: 'Privacy Policy',
              style: linkStyle,
              onTap: () => AppDialog.info(
                context,
                title: 'Privacy Policy',
                message: isMock
                    ? 'The full policy will be published before launch. This '
                          'build signs in with a mock provider, contacts no '
                          'Google service, and keeps your answers on this '
                          'device only.'
                    : 'The full policy will be published before launch. '
                          'Signing in asks Google who you are; your name and '
                          'email come back to this phone and stay here. '
                          'Everything you record — transactions, budgets, '
                          'goals — is stored on this device only.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
            horizontal: AppSpacing.xxs,
          ),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
