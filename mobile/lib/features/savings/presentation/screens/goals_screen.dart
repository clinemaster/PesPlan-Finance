import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../domain/goal_progress.dart';
import '../providers/savings_providers.dart';
import '../widgets/savings_widgets.dart';

/// What the user is saving toward, and how far along it is.
///
/// The total leads, because "how much have I got" is the question that
/// brings someone to this screen. The goals follow, closest to done
/// first, and anything already finished sits in its own section below —
/// visible rather than archived, because finished goals are the evidence
/// that saving works.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(savingsBoardProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Goals',
        actions: [
          AppIconButton(
            icon: AppIcons.add,
            tooltip: 'Create goal',
            onPressed: () => context.push(Routes.goalNew),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: switch (board) {
          AsyncData(:final value) when value.isEmpty => const _Empty(),
          AsyncData(:final value) => _Board(board: value),
          AsyncError(:final error) => ErrorState(
            message: 'We could not load your goals. $error',
            onRetry: () => ref.invalidate(savingsBoardProvider),
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.board});

  final SavingsBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final today = ref.watch(clockProvider)();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      children: [
        SavingsTotalCard(
          board: board,
          onCreate: () => context.push(Routes.goalNew),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        SectionHeader(
          title: 'Saving toward',
          subtitle: board.active.isEmpty ? null : 'The closest to done first',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),

        if (board.active.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing in progress',
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  board.hasCompleted
                      ? 'Every goal you set has been reached. Start another '
                            'when you are ready.'
                      : 'Create a goal to start putting money aside.',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.outlined(
                  label: 'Create goal',
                  icon: AppIcons.add,
                  onPressed: () => context.push(Routes.goalNew),
                ),
              ],
            ),
          )
        else
          for (final progress in board.active) ...[
            GoalCard(
              progress: progress,
              today: today,
              onTap: () => context.push(Routes.goalDetail(progress.goal.id)),
            ),
            if (progress != board.active.last)
              const SizedBox(height: AppSpacing.md),
          ],

        if (board.hasCompleted) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          SectionHeader(
            title: 'Reached',
            subtitle: board.completedCount == 1
                ? 'One goal you finished'
                : '${board.completedCount} goals you finished',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final progress in board.completed) ...[
            GoalCard(
              progress: progress,
              today: today,
              onTap: () => context.push(Routes.goalDetail(progress.goal.id)),
            ),
            if (progress != board.completed.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    // Centred when it fits, scrolling when it does not: the invitation
    // runs to several lines on a small screen, and a centred column with
    // no scroll view puts its own button off the bottom.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: EmptyState(
                icon: AppIcons.savings,
                title: 'No savings goals yet.',
                message:
                    'Start saving toward something that matters to you. '
                    'Set a target, put money aside when you can, and watch '
                    'it add up.',
                actionLabel: 'Create goal',
                onAction: () => context.push(Routes.goalNew),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(height: 240, radius: AppRadius.card),
          SizedBox(height: AppSpacing.sectionGap),
          Skeleton(height: 150, radius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 150, radius: AppRadius.card),
        ],
      ),
    );
  }
}
