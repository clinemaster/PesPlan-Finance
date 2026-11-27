import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/goal_progress.dart';
import '../../domain/goal_timing.dart';
import '../providers/savings_providers.dart';
import '../widgets/savings_widgets.dart';

/// One goal: where it stands, how it got there, and what can be done to
/// it.
///
/// A screen rather than a sheet, unlike budgets: a goal carries a history
/// that grows, and a list that scrolls inside a sheet behind a half-dimmed
/// screen is harder to read than one with the display to itself.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(goalProgressProvider(id));

    return Scaffold(
      appBar: AppTopBar(
        title: switch (progress) {
          AsyncData(:final value) when value != null => value.goal.name,
          _ => 'Goal',
        },
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: switch (progress) {
          AsyncData(:final value) when value != null => _Detail(
            progress: value,
          ),
          AsyncData() => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Center(
              child: EmptyState(
                icon: AppIcons.error,
                title: 'That goal is gone',
                message:
                    'It may have been deleted. Go back to see your current '
                    'goals.',
                actionLabel: 'Back to goals',
                onAction: () => context.pop(),
              ),
            ),
          ),
          AsyncError(:final error) => ErrorState(
            message: 'We could not open that goal. $error',
            onRetry: () => ref.invalidate(goalProgressProvider(id)),
          ),
          _ => const LoadingState(message: 'Opening goal'),
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final goal = progress.goal;
    final today = ref.watch(clockProvider)();
    final movements = ref.watch(goalMovementsProvider(goal.id));
    final accent = progress.isComplete ? finance.success : finance.income;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.xxl,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryIcon(
                          category: goal.iconKey,
                          size: AppIconSize.huge,
                          tint: progress.isComplete
                              ? finance.successSurface
                              : finance.incomeSurface,
                          iconColor: progress.isComplete
                              ? finance.successText
                              : finance.incomeText,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                progress.isComplete ? 'Saved' : 'Saved so far',
                                style: AppTypography.caption.copyWith(
                                  color: finance.textSecondary,
                                ),
                              ),
                              MoneyText(
                                progress.saved,
                                size: MoneySize.large,
                                colorBySign: false,
                                color: finance.textPrimary,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'of ${goal.target.format()}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: finance.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppProgressBar(
                      value: progress.barValue,
                      color: accent,
                      semanticLabel:
                          '${progress.saved.semanticLabel} saved of '
                          '${goal.target.semanticLabel}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (progress.isComplete)
                      _CompletionNote(progress: progress)
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${progress.remaining.format()} to go',
                              style: AppTypography.bodySmall.copyWith(
                                color: finance.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${progress.cappedPercent}%',
                            style: AppTypography.label.copyWith(color: accent),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    _Row(label: 'Target', value: goal.target.format()),
                    const AppDivider(),
                    _Row(label: 'Saved', value: progress.saved.format()),
                    const AppDivider(),
                    _Row(
                      label: 'Remaining',
                      value: progress.remaining.format(),
                    ),
                    const AppDivider(),
                    _Row(label: 'Put in', value: progress.contributed.format()),
                    if (progress.withdrawn.minorUnits > 0) ...[
                      const AppDivider(),
                      _Row(
                        label: 'Taken out',
                        value: progress.withdrawn.format(),
                      ),
                    ],
                    const AppDivider(),
                    _Row(
                      label: 'Target date',
                      value: goal.targetDate == null
                          ? 'No date set'
                          : DateLabels.full(goal.targetDate!),
                    ),
                    if (goal.targetDate != null && !progress.isComplete) ...[
                      const AppDivider(),
                      _Row(
                        label: 'Time left',
                        value:
                            GoalTiming.remaining(goal.targetDate, today) ?? '—',
                      ),
                    ],
                    const AppDivider(),
                    _Row(
                      label: 'Started',
                      value: DateLabels.full(goal.createdAt),
                    ),
                    if (goal.description.trim().isNotEmpty) ...[
                      const AppDivider(),
                      _Row(label: 'Note', value: goal.description),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              SectionHeader(
                title: 'History',
                subtitle: progress.hasMovements
                    ? '${progress.movementCount} '
                          '${progress.movementCount == 1 ? 'movement' : 'movements'}'
                    : null,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),

              switch (movements) {
                AsyncData(:final value) when value.isEmpty => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nothing recorded yet',
                        style: AppTypography.titleCard.copyWith(
                          color: finance.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add what you put aside and it will appear here, '
                        'newest first.',
                        style: AppTypography.bodySmall.copyWith(
                          color: finance.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AsyncData(:final value) => AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardPadding,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      for (final movement in value) ...[
                        MovementRow(movement: movement, today: today),
                        if (movement != value.last) const AppDivider(),
                      ],
                    ],
                  ),
                ),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not load this history. $error',
                  onRetry: () => ref.invalidate(goalMovementsProvider(goal.id)),
                ),
                _ => const SkeletonList(itemCount: 3),
              },

              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      label: 'Edit',
                      icon: AppIcons.edit,
                      onPressed: () => context.push(Routes.goalEdit(goal.id)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.destructive(
                      label: 'Delete',
                      icon: AppIcons.delete,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // The two actions this screen exists for, pinned where a thumb
        // reaches them rather than below however long the history is.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stacked, not side by side.
              //
              // Two halves of a 393pt phone leave 134pt inside a button's
              // padding, and "Add money" needs 145 — so the label came
              // back as "Add mone…". Adding money is also the frequent
              // action and taking it out is the rare one, which is what
              // the emphasis should say anyway.
              AppButton.primary(
                label: 'Add money',
                icon: AppIcons.add,
                onPressed: () =>
                    context.push(Routes.goalContribute(progress.goal.id)),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton.text(
                label: 'Take out',
                icon: AppIcons.expense,
                // Nothing in the goal is nothing to take: the button is
                // disabled rather than hidden, so the action stays where
                // the user learned it was.
                onPressed: progress.saved.minorUnits <= 0
                    ? null
                    : () => context.push(Routes.goalWithdraw(progress.goal.id)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final goal = progress.goal;

    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this goal?',
      // Names the goal and what it holds: a confirmation that just says
      // "this goal" is one people agree to without reading.
      message: progress.hasMovements
          ? '${goal.name} and its ${progress.movementCount} recorded '
                'movements will be removed. The '
                '${progress.saved.format()} set aside is not a real '
                'account, so no money moves.'
          : '${goal.name} will be removed from your goals.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed != true) return;

    await ref.read(savingsActionsProvider).delete(goal.id);

    if (!context.mounted) return;
    context.pop();
    AppSnackbar.success(context, 'Goal deleted');
  }
}

/// The one moment this feature is allowed to be pleased.
class _CompletionNote extends StatelessWidget {
  const _CompletionNote({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: finance.successSurface,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.success,
            size: AppIconSize.sm,
            color: finance.successText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Target reached. You saved '
              '${progress.goal.target.format()} for this.',
              style: AppTypography.caption.copyWith(color: finance.successText),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: finance.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                color: finance.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
