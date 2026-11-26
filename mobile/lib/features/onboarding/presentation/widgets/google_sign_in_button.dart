import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import 'google_logo.dart';

/// The "Continue with Google" button.
///
/// Not an [AppButton]: a third-party sign-in button has conventions of its
/// own — a white surface, a neutral border and the provider's own mark — and
/// users recognise it by them. Forcing it into the primary button's brand
/// colours would make it look like one of our actions rather than a handoff
/// to Google.
///
/// It does still take its height, radius, type scale and motion from the
/// design system, so it sits correctly beside everything else and does not
/// become a second, divergent button style.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  /// Null disables the button. While [isLoading] the button also ignores
  /// taps, but for a different reason: the action is already running.
  final VoidCallback? onPressed;

  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? 'Signing in with Google' : label,
      excludeSemantics: true,
      child: SizedBox(
        height: AppSpacing.controlHeight,
        width: double.infinity,
        child: Material(
          // Google's button is white in both themes. On our dark surface a
          // white chip is also the clearest possible affordance, so this is
          // the rare control that does not follow the theme.
          color: enabled ? Colors.white : finance.surfaceMuted,
          borderRadius: AppRadius.buttonAll,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: AppRadius.buttonAll,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: AppRadius.buttonAll,
                border: Border.all(
                  color: enabled ? const Color(0xFFDADCE0) : finance.border,
                  width: AppStroke.hairline,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: isLoading
                      ? SizedBox.square(
                          key: const ValueKey('google-spinner'),
                          dimension: AppIconSize.md,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              finance.textSecondary,
                            ),
                          ),
                        )
                      : Row(
                          key: const ValueKey('google-label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoogleLogo(size: AppIconSize.md),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              label,
                              style: AppTypography.button.copyWith(
                                // Google's own button uses a near-black
                                // label on white, not our ink colour.
                                color: enabled
                                    ? const Color(0xFF3C4043)
                                    : finance.textDisabled,
                              ),
                            ),
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
}
