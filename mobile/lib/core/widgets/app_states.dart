import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_motion.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import 'app_button.dart';

/// Nothing here yet.
///
/// ## Why an empty state needs a design at all
///
/// A blank screen reads as broken. For a first-time user — the audience this
/// app is built for — the empty state *is* the onboarding: it says what the
/// screen is for and offers the one action that fills it.
///
/// So the shape is fixed: a calm icon, a plain-language title, one sentence
/// of explanation, and at most one primary action. No illustration library,
/// no empty-state mascot — this is a money app, and whimsy here reads as
/// unserious.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = AppIcons.transactions,
    this.actionLabel,
    this.onAction,
    this.actionIcon = AppIcons.add,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The icon on the action. Adding something is the common case and
  /// stays the default, but "Try again" with a plus on it says the
  /// wrong thing.
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: finance.surfaceMuted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: AppIconSize.huge,
              color: finance.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: AppTypography.titleSection.copyWith(
              color: finance.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: finance.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppButton.primary(
              label: actionLabel!,
              onPressed: onAction,
              isFullWidth: false,
              icon: actionIcon,
            ),
          ],
        ],
      ),
    );
  }
}

/// Something went wrong.
///
/// Separate from [EmptyState] on purpose: "you have no transactions" and
/// "we could not load your transactions" are different facts, and showing the
/// empty state on a failed request tells the user their data is gone.
///
/// The message should name what failed and what to do. "No internet
/// connection. Check your connection and try again." — not "Error 500".
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    super.key,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = AppIcons.error,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: finance.expenseSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: AppIconSize.huge,
              color: finance.expenseText,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: AppTypography.titleSection.copyWith(
              color: finance.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: finance.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppButton.outlined(
              label: retryLabel,
              onPressed: onRetry,
              isFullWidth: false,
              icon: AppIcons.refresh,
            ),
          ],
        ],
      ),
    );
  }
}

/// A centred spinner with an optional message.
///
/// Prefer a [SkeletonList] where the shape of the incoming content is known —
/// a skeleton tells the user what is arriving, a spinner only that something
/// is. A spinner is right for a short, indeterminate wait such as submitting
/// a form.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label: message ?? 'Loading',
      liveRegion: true,
      // The label already is the message; without this the same words are
      // announced twice.
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(context.colors.primary),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                style: AppTypography.bodyMedium.copyWith(
                  color: finance.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering placeholder block.
///
/// ## Why the shimmer is subtle and slow
///
/// A fast, high-contrast shimmer is a vestibular irritant and makes a loading
/// screen feel frantic. This runs one 1.2s cycle between two near-identical
/// greys, which reads as "working" without drawing the eye. It also respects
/// `MediaQuery.disableAnimations`, so a user who has asked the OS to reduce
/// motion gets a static block instead.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.shape = BoxShape.rectangle,
  });

  /// A circular placeholder, e.g. where a category icon will land.
  const Skeleton.circle({Key? key, double size = 40})
    : this(key: key, width: size, height: size, shape: BoxShape.circle);

  /// A single line of text.
  const Skeleton.text({Key? key, double? width, double height = 14})
    : this(key: key, width: width, height: height);

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final base = finance.surfaceMuted;
    final highlight = Color.alphaBlend(
      finance.border.withValues(alpha: 0.6),
      base,
    );

    // Hidden from assistive tech: a screen reader should hear the
    // LoadingState announcement, not a list of empty boxes.
    return ExcludeSemantics(
      child: reduceMotion
          ? _box(base)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) =>
                  _box(Color.lerp(base, highlight, _controller.value)!),
            ),
    );
  }

  Widget _box(Color color) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: color,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle
            ? null
            : BorderRadius.circular(widget.radius),
      ),
    );
  }
}

/// A list of transaction-shaped skeletons.
///
/// Mirrors [TransactionTile]'s layout — icon, two lines, right-aligned
/// amount — so the content does not jump when it arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Skeleton.circle(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Widths vary a little so the list does not look
                        // mechanically striped.
                        Skeleton.text(width: i.isEven ? 160 : 120),
                        const SizedBox(height: AppSpacing.sm),
                        Skeleton.text(width: i.isEven ? 90 : 110, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Skeleton(width: 72, height: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
