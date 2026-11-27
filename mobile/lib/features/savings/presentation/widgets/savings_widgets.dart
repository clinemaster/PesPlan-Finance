import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/goal_movement.dart';
import '../../domain/goal_progress.dart';
import '../../domain/goal_timing.dart';
import '../../domain/savings_goal.dart';

/// Everything set aside, across the goals still being saved toward.
class SavingsTotalCard extends StatelessWidget {
  const SavingsTotalCard({
    required this.board,
    required this.onCreate,
    super.key,
  });

  final SavingsBoard board;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Set aside',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              AppBadge(
                label: board.activeCount == 1
                    ? '1 goal'
                    : '${board.activeCount} goals',
                icon: AppIcons.goals,
                tone: BadgeTone.savings,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Neutral ink, not sign colouring: savings are a quantity, and
          // the default would paint them income-green as if they had just
          // been earned.
          MoneyText(
            board.totalSaved,
            size: MoneySize.hero,
            colorBySign: false,
            color: finance.textPrimary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'of ${board.totalTarget.format()} across active goals',
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppProgressBar(
            value: board.barValue,
            color: finance.income,
            semanticLabel:
                '${board.totalSaved.semanticLabel} saved of '
                '${board.totalTarget.semanticLabel}',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${board.percent}% of what you are saving toward',
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Create goal',
            icon: AppIcons.add,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

/// One savings goal, as the list shows it.
class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.progress,
    required this.today,
    required this.onTap,
    super.key,
  });

  final GoalProgress progress;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final goal = progress.goal;
    final timing = GoalTiming.remaining(goal.targetDate, today);
    final accent = progress.isComplete ? finance.success : finance.income;

    return AppCard(
      onTap: onTap,
      child: Semantics(
        button: true,
        label:
            '${goal.name}, ${progress.saved.semanticLabel} of '
            '${goal.target.semanticLabel}, '
            '${progress.isComplete ? 'complete' : '${progress.cappedPercent} percent'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(category: goal.iconKey, size: AppIconSize.xl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleCard.copyWith(
                          color: finance.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${progress.saved.format()} of '
                        '${goal.target.format()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: finance.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${progress.cappedPercent}%',
                  style: AppTypography.label.copyWith(color: accent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(
              value: progress.barValue,
              color: accent,
              semanticLabel: goal.name,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.isComplete
                        ? 'Target reached'
                        : '${progress.remaining.format()} to go',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: progress.isComplete
                          ? finance.successText
                          : finance.textTertiary,
                    ),
                  ),
                ),
                if (progress.isComplete)
                  StatusIndicator(
                    label: 'Complete',
                    tone: StatusTone.success,
                    compact: true,
                  )
                else if (timing != null)
                  Text(
                    timing,
                    style: AppTypography.caption.copyWith(
                      color: finance.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One contribution or withdrawal in a goal's history.
class MovementRow extends StatelessWidget {
  const MovementRow({required this.movement, required this.today, super.key});

  final GoalMovement movement;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final isIn = movement.isContribution;

    // Direction is carried by the icon, the words and the sign — not by
    // colour alone, which roughly one man in twelve cannot separate.
    final accent = isIn ? finance.income : finance.expense;
    final text = isIn ? finance.incomeText : finance.expenseText;

    return Semantics(
      label:
          '${movement.kind.label}, ${movement.amount.semanticLabel}, '
          '${DateLabels.full(movement.date)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: AppIconSize.xl,
              height: AppIconSize.xl,
              decoration: BoxDecoration(
                color: isIn ? finance.incomeSurface : finance.expenseSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIn ? AppIcons.income : AppIcons.expense,
                size: AppIconSize.sm,
                color: text,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: finance.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    // The kind is only repeated here when the title is
                    // the user's own note. Without a note the title is
                    // already "Contribution", and "Contribution ·
                    // Contribution · Today" is what the naive version
                    // reads as.
                    movement.description.trim().isEmpty
                        ? DateLabels.rowLabel(movement.date, today)
                        : '${movement.kind.label} · '
                              '${DateLabels.rowLabel(movement.date, today)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${isIn ? '+' : '−'}${movement.amount.format()}',
              style: AppTypography.amountSmall.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The short list of pictures a goal can wear.
class GoalIconPicker extends StatelessWidget {
  const GoalIconPicker({
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final String selectedKey;
  final ValueChanged<GoalIcon> onSelected;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Picture',
          style: AppTypography.label.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final icon in GoalIcon.all)
              _IconChip(
                icon: icon,
                isSelected: icon.key == selectedKey,
                onTap: () => onSelected(icon),
              ),
          ],
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final GoalIcon icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final foreground = isSelected
        ? context.colors.onPrimary
        : finance.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: icon.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? context.colors.primary : finance.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Center with widthFactor, not alignment: a Wrap hands each
            // child unbounded width, and a Container with an alignment
            // takes all of it — one full-width chip per row.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.forCategory(icon.key),
                    size: AppIconSize.sm,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    icon.label,
                    style: AppTypography.labelSmall.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
