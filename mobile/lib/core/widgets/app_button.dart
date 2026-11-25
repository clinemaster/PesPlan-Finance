import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_motion.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';

/// What a button looks like, by the weight of the action it performs.
enum AppButtonVariant {
  /// The one action the screen wants. At most one per view.
  primary,

  /// A supporting action: filled, but tinted rather than solid.
  secondary,

  /// An alternative action of equal standing. Outlined.
  outlined,

  /// A low-weight action: "Skip", "Learn more".
  text,

  /// Deletes or discards. Red, and never the default focus.
  destructive,
}

enum AppButtonSize { normal, small }

/// The button for every action in LifePilot Finance.
///
/// ## Why one widget instead of five
///
/// Five wrappers around Material's button family drift apart: one gets a new
/// height, another a different disabled colour. One widget with a [variant]
/// keeps height, radius, type scale and disabled treatment identical, so
/// changing a button's weight never changes layout.
///
/// ## Loading and disabled are different states
///
/// A null [onPressed] is *disabled*: the action is unavailable. [isLoading] is
/// *working*: the action was accepted and is in flight. They look different
/// and they announce differently to a screen reader — conflating them is how
/// a user ends up tapping a button that already fired.
///
/// While loading, the label stays in place and the spinner replaces the icon
/// slot, so the button does not resize and the surrounding layout does not
/// jump.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  });

  /// Convenience constructor for the primary action.
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  }) : variant = AppButtonVariant.text;

  const AppButton.destructive({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = AppButtonSize.normal,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.destructive;

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// The action is in flight. Taps are ignored and a spinner shows.
  final bool isLoading;

  /// Buttons are full width by default — the easiest target for one-handed
  /// use on a phone. Text buttons default to hugging their label.
  final bool isFullWidth;

  /// Overrides the spoken label where the visible text is not self-explanatory
  /// out of context (e.g. "Continue" on a step the reader cannot see).
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  double get _height => size == AppButtonSize.small
      ? AppSpacing.controlHeightSmall
      : AppSpacing.controlHeight;

  TextStyle get _textStyle => size == AppButtonSize.small
      ? AppTypography.buttonSmall
      : AppTypography.button;

  double get _iconSize =>
      size == AppButtonSize.small ? AppIconSize.sm : AppIconSize.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final finance = context.finance;

    final (
      Color background,
      Color foreground,
      Color? borderColor,
    ) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      AppButtonVariant.secondary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        null,
      ),
      AppButtonVariant.outlined => (
        Colors.transparent,
        colors.primary,
        finance.borderStrong,
      ),
      AppButtonVariant.text => (Colors.transparent, colors.primary, null),
      AppButtonVariant.destructive => (finance.expense, colors.onError, null),
    };

    // Disabled uses a muted fill and the disabled ink tier. WCAG exempts
    // inactive controls from contrast, and a disabled button that still looks
    // pressable is worse than one that clearly is not.
    final effectiveBackground = _enabled
        ? background
        : (variant == AppButtonVariant.text ||
                  variant == AppButtonVariant.outlined
              ? Colors.transparent
              : finance.surfaceMuted);
    final effectiveForeground = _enabled ? foreground : finance.textDisabled;

    final child = _IconOrSpinner(
      duration: AppMotion.fast,
      isLoading: isLoading,
      loading: SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(effectiveForeground),
        ),
      ),
      idle: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: _iconSize, color: effectiveForeground),
    );

    final content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null || isLoading) ...[
          child,
          const SizedBox(width: AppSpacing.sm),
        ],
        // Flexible so a long label in a large text scale ellipsises rather
        // than overflowing the button.
        Flexible(
          child: Text(
            label,
            style: _textStyle.copyWith(color: effectiveForeground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      // Announced so a screen-reader user knows the tap was accepted.
      hint: isLoading ? 'Working' : null,
      excludeSemantics: true,
      child: Material(
        color: effectiveBackground,
        borderRadius: AppRadius.buttonAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _enabled ? onPressed : null,
          borderRadius: AppRadius.buttonAll,
          child: Container(
            height: _height,
            padding: EdgeInsets.symmetric(
              horizontal: size == AppButtonSize.small
                  ? AppSpacing.lg
                  : AppSpacing.xl,
            ),
            decoration: borderColor == null
                ? null
                : BoxDecoration(
                    borderRadius: AppRadius.buttonAll,
                    border: Border.all(
                      color: _enabled ? borderColor : finance.border,
                    ),
                  ),
            // No `alignment:` here. Setting it makes a Container expand to
            // fill its parent's constraints, which silently defeated
            // isFullWidth: false. The Row already centres its own content.
            child: content,
          ),
        ),
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Crossfades between a spinner and an icon without changing size.
class _IconOrSpinner extends StatelessWidget {
  const _IconOrSpinner({
    required this.duration,
    required this.isLoading,
    required this.loading,
    required this.idle,
  });

  final Duration duration;
  final bool isLoading;
  final Widget loading;
  final Widget idle;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: duration,
      firstChild: loading,
      secondChild: idle,
      crossFadeState: isLoading
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      alignment: Alignment.center,
    );
  }
}

/// An icon-only button.
///
/// [tooltip] is required, not optional: an icon alone is not a label, and
/// without one a screen reader announces nothing useful. It doubles as the
/// hover tooltip and the semantic label.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.color,
    this.background,
    this.size = AppIconSize.lg,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Doubles as the semantic label. Required for exactly that reason.
  final String tooltip;

  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: background ?? Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            // 48x48 regardless of icon size: the painted glyph can be small,
            // the target cannot.
            child: SizedBox(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              child: Center(
                child: Icon(
                  icon,
                  size: size,
                  color: enabled
                      ? (color ?? finance.textSecondary)
                      : finance.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
