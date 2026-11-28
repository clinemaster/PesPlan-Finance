import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/subscription.dart';

/// Leaves a settings screen.
///
/// Normally a pop, because these are pushed over the hub. A deep link
/// straight to one has nothing underneath, so it falls back to the hub
/// rather than throwing — a user who followed a link should not be
/// stranded on a screen with no way back.
void leaveSettings(BuildContext context, {String fallback = Routes.settings}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// One row inside a settings card.
///
/// ## Not a ListTile
///
/// `ListTile` paints its background and ink on the nearest [Material],
/// which here is behind [AppCard]'s own decorated surface — so the
/// ripple would be drawn underneath the card and never seen. This draws
/// its own.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// The current setting, shown on the right of a row that opens
  /// somewhere else. A row that says "Currency" and nothing else makes
  /// the user open it to find out what it is set to.
  final String? value;

  /// A switch, or anything else that is the control itself.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final titleColor = isDestructive
        ? finance.expenseText
        : finance.textPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppIconSize.md,
              color: isDestructive
                  ? finance.expenseText
                  : finance.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: finance.textSecondary,
                ),
              ),
            ),
          ?trailing,
          if (trailing == null && onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.md,
              color: finance.textTertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: value == null ? title : '$title, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: content,
      ),
    );
  }
}

/// A titled card of rows, with dividers between them.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.rows,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              for (final row in rows) ...[
                row,
                if (row != rows.last) const AppDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A note that a control is not wired to anything yet.
///
/// Said in the interface rather than only in a changelog: a switch that
/// looks real and does nothing is the fastest way to lose a user's trust
/// in every other switch on the screen.
class PlaceholderNote extends StatelessWidget {
  const PlaceholderNote({required this.message, super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: finance.infoSurface,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? AppIcons.info,
            size: AppIconSize.sm,
            color: finance.infoText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: finance.infoText),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan, as a card.
class PlanCard extends StatelessWidget {
  const PlanCard({required this.subscription, super.key, this.onManage});

  final Subscription subscription;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final isPremium = subscription.isPremium;

    return AppCard(
      onTap: onManage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your plan',
                  style: AppTypography.label.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              AppBadge(
                label: subscription.plan.label,
                icon: isPremium ? AppIcons.success : AppIcons.info,
                tone: isPremium ? BadgeTone.income : BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subscription.statusLine,
            style: AppTypography.titleCard.copyWith(color: finance.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPremium
                ? 'Every limit lifted, and the deeper reports unlocked.'
                : 'Everything you need to run your money. Premium adds '
                      'higher limits and deeper reports.',
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Free against Premium, line by line.
class FeatureComparison extends StatelessWidget {
  const FeatureComparison({required this.features, super.key, this.title});

  final List<PlanFeature> features;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTypography.label.copyWith(color: finance.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              const Expanded(flex: 4, child: SizedBox.shrink()),
              Expanded(
                flex: 3,
                child: Text(
                  'Free',
                  textAlign: TextAlign.right,
                  style: AppTypography.labelSmall.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Premium',
                  textAlign: TextAlign.right,
                  style: AppTypography.labelSmall.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final feature in features) ...[
            const AppDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      feature.title,
                      style: AppTypography.bodySmall.copyWith(
                        color: finance.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      feature.free,
                      textAlign: TextAlign.right,
                      style: AppTypography.caption.copyWith(
                        color: finance.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      feature.premium,
                      textAlign: TextAlign.right,
                      style: AppTypography.caption.copyWith(
                        color: feature.differs
                            ? context.colors.primary
                            : finance.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
