import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../../reports/domain/report_period.dart';
import '../../domain/budget_progress.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_detail_sheet.dart';
import '../widgets/budget_widgets.dart';

/// The month's plans, and how they are going.
///
/// The overall budget leads because it answers "can I afford this" in one
/// figure. The categories follow in order of pressure rather than size,
/// so whatever needs attention is at the top.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetMonthProvider);
    final controller = ref.read(budgetMonthProvider.notifier);
    final board = ref.watch(budgetBoardProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppTopBar(
        title: 'Budgets',
        actions: [
          AppIconButton(
            icon: AppIcons.add,
            tooltip: 'Create budget',
            onPressed: () => context.push(Routes.budgetNew),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                0,
              ),
              child: BudgetMonthStepper(
                title: '${ReportPeriod.monthName(month.month)} ${month.year}',
                subtitle: month.isCurrent(now) ? 'this month' : null,
                onPrevious: controller.previous,
                onNext: month.canGoNext(now) ? controller.next : null,
              ),
            ),
            Expanded(
              child: switch (board) {
                AsyncData(:final value) when value.isEmpty => _Empty(
                  isCurrent: month.isCurrent(now),
                ),
                AsyncData(:final value) => _Board(board: value),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not load your budgets. $error',
                  onRetry: () => ref.invalidate(budgetBoardProvider),
                ),
                _ => const _Loading(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.board});

  final BudgetBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      children: [
        if (board.overall != null) ...[
          OverallBudgetCard(
            progress: board.overall!,
            onTap: () => BudgetDetailSheet.show(context, board.overall!),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ] else ...[
          _NoOverallCard(),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        SectionHeader(
          title: 'By category',
          subtitle: board.categories.isEmpty
              ? null
              : 'The ones needing attention first',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),

        if (board.categories.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No category budgets yet',
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Set a limit for the things you spend most on, and this '
                  'list will show how each is going.',
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.outlined(
                  label: 'Add a category budget',
                  icon: AppIcons.add,
                  onPressed: () => context.push(Routes.budgetNew),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final progress in board.categories) ...[
                  CategoryBudgetRow(
                    progress: progress,
                    onTap: () => BudgetDetailSheet.show(context, progress),
                  ),
                  if (progress != board.categories.last) const AppDivider(),
                ],
              ],
            ),
          ),

        if (board.hasUnbudgetedSpending) ...[
          const SizedBox(height: AppSpacing.lg),
          _UnbudgetedNote(amount: board.unbudgetedSpending),
        ],

        const SizedBox(height: AppSpacing.sectionGap),
        AppButton.outlined(
          label: 'Create budget',
          icon: AppIcons.add,
          onPressed: () => context.push(Routes.budgetNew),
        ),
      ],
    );
  }
}

/// Spending in categories nobody budgeted.
///
/// Without it, a category list that adds up to less than the month's
/// total looks like a bug — and unbudgeted spending is usually the part a
/// user did not realise was happening.
class _UnbudgetedNote extends StatelessWidget {
  const _UnbudgetedNote({required this.amount});

  final Money amount;

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
          Icon(AppIcons.info, size: AppIconSize.sm, color: finance.infoText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${amount.format()} went on things with no budget set.',
              style: AppTypography.caption.copyWith(color: finance.infoText),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoOverallCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No overall budget',
            style: AppTypography.titleCard.copyWith(color: finance.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set one limit for the whole month to see at a glance how much '
            'is left.',
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.outlined(
            label: 'Set a monthly budget',
            icon: AppIcons.add,
            onPressed: () => context.push(Routes.budgetNewOfKind('overall')),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isCurrent});

  /// A past month with no budgets is a different fact from this month
  /// with none: there is nothing to plan retrospectively, so the
  /// invitation changes.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    // Centred when it fits, scrolling when it does not.
    //
    // The invitation runs to four lines on a 320px screen, and a centred
    // column with no scroll view puts its own button off the bottom —
    // which is how an empty state becomes a dead end.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: EmptyState(
                icon: AppIcons.budgets,
                title: 'Start planning your spending.',
                message: isCurrent
                    ? 'Create a budget to see how your money is being used.'
                    : 'No budgets were set for this month. Step forward to this '
                          'month to plan ahead.',
                actionLabel: isCurrent ? 'Create budget' : null,
                onAction: isCurrent
                    ? () => context.push(Routes.budgetNew)
                    : null,
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
          Skeleton(height: 220, radius: AppRadius.card),
          SizedBox(height: AppSpacing.sectionGap),
          Skeleton(height: 240, radius: AppRadius.card),
        ],
      ),
    );
  }
}
