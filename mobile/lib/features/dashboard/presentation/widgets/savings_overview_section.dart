import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/dashboard_data.dart';

/// Progress toward what the user is saving for.
///
/// Two goals at most. A dashboard that lists every goal becomes the Goals
/// screen with worse layout; two is enough to remind someone what they are
/// working toward, which is the behaviour this card is trying to support.
class SavingsOverviewSection extends StatelessWidget {
  const SavingsOverviewSection({required this.savings, super.key});

  final SavingsOverview? savings;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final current = savings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Savings goals',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.goals),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (current == null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No goals yet',
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Name something you are saving for and track it here.',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            onTap: () => context.go(Routes.goals),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set aside',
                            style: AppTypography.bodySmall.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          MoneyText(
                            current.totalSaved,
                            size: MoneySize.large,
                            colorBySign: false,
                            color: finance.savingsText,
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      label:
                          '${current.activeGoals} '
                          '${current.activeGoals == 1 ? 'goal' : 'goals'}',
                      tone: BadgeTone.savings,
                      icon: AppIcons.goals,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'of ${current.totalTarget.format()} target',
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final goal in current.previews) ...[
                  _GoalRow(goal: goal),
                  if (goal != current.previews.last)
                    const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final GoalPreview goal;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label:
          '${goal.name}: ${goal.saved.semanticLabel} saved of '
          '${goal.target.semanticLabel}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The name and the amounts get a line each. Side by side they
          // overflow once a goal name is more than a word or two, and a
          // goal called "Deposit for the shop in Kariakoo" is the normal
          // case rather than the awkward one.
          Text(
            goal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: finance.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${goal.saved.format()} of ${goal.target.format()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            value: goal.ratio,
            color: finance.savings,
            semanticLabel: goal.name,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            goal.caption,
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
        ],
      ),
    );
  }
}
