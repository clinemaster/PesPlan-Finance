import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/goal_movement.dart';
import '../../domain/goal_progress.dart';
import '../../domain/savings_validator.dart';
import '../providers/savings_providers.dart';

/// Putting money into a goal, or taking some back out.
///
/// One screen for both directions: the fields are identical and only the
/// rules and the words differ, so two screens would be the same screen
/// twice with one of them quietly falling behind.
class GoalMovementScreen extends ConsumerStatefulWidget {
  const GoalMovementScreen({
    required this.goalId,
    required this.kind,
    super.key,
  });

  final String goalId;
  final MovementKind kind;

  @override
  ConsumerState<GoalMovementScreen> createState() => _GoalMovementScreenState();
}

class _GoalMovementScreenState extends ConsumerState<GoalMovementScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _date;
  int? _minorUnits;
  bool _showErrors = false;
  bool _isSaving = false;

  bool get _isContribution => widget.kind.isContribution;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _amountError(int savedMinorUnits) => _isContribution
      ? SavingsValidator.contribution(_minorUnits)
      : SavingsValidator.withdrawal(_minorUnits, savedMinorUnits);

  Future<void> _save(GoalProgress progress) async {
    final now = ref.read(clockProvider)();
    final date = _date ?? now;

    final failed =
        _amountError(progress.saved.minorUnits) != null ||
        SavingsValidator.movementDate(date, now) != null ||
        SavingsValidator.description(_descriptionController.text) != null;

    if (failed) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _isSaving = true);

    final actions = ref.read(savingsActionsProvider);

    try {
      await actions.addMovement(
        GoalMovement(
          id: actions.newId(),
          goalId: widget.goalId,
          kind: widget.kind,
          amount: Money(_minorUnits!),
          date: date,
          recordedAt: now,
          description: _descriptionController.text.trim(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, 'Could not record that. $error');
      return;
    }

    if (!mounted) return;
    AppSnackbar.success(
      context,
      _isContribution
          ? 'Added to ${progress.goal.name}'
          : 'Taken out of ${progress.goal.name}',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(goalProgressProvider(widget.goalId));

    return Scaffold(
      appBar: AppTopBar(
        title: _isContribution ? 'Add money' : 'Take money out',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: switch (progress) {
          AsyncData(:final value) when value != null => _form(context, value),
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
            onRetry: () => ref.invalidate(goalProgressProvider(widget.goalId)),
          ),
          _ => const LoadingState(message: 'Opening goal'),
        },
      ),
    );
  }

  /// The form itself, built as a method rather than a separate
  /// widget: it reads and writes this screen's own state, and a
  /// child widget reaching back into a State to call setState is
  /// both a lint and a seam waiting to break.
  Widget _form(BuildContext context, GoalProgress progress) {
    final finance = context.finance;
    final now = ref.watch(clockProvider)();
    final date = _date ?? now;
    final isContribution = _isContribution;

    final amountError = _showErrors
        ? _amountError(progress.saved.minorUnits)
        : null;
    final dateError = _showErrors
        ? SavingsValidator.movementDate(date, now)
        : null;
    final descriptionError = _showErrors
        ? SavingsValidator.description(_descriptionController.text)
        : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.xxl,
            ),
            children: [
              // What the goal holds right now, stated before the field
              // rather than after a refusal: a user taking money out
              // needs to know the ceiling while they type, not once they
              // have hit it.
              AppCard(
                child: Row(
                  children: [
                    CategoryIcon(
                      category: progress.goal.iconKey,
                      size: AppIconSize.xl,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: finance.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            isContribution
                                ? '${progress.saved.format()} of '
                                      '${progress.goal.target.format()} saved'
                                : '${progress.saved.format()} available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              AmountField(
                label: isContribution ? 'Amount to add' : 'Amount to take out',
                controller: _amountController,
                autofocus: true,
                error: amountError,
                helper: isContribution
                    ? 'Money you have set aside for this goal'
                    : 'Cannot be more than this goal holds',
                onChangedMinorUnits: (value) {
                  _minorUnits = value;
                  if (_showErrors) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              DateField(
                label: 'Date',
                value: DateLabels.full(date),
                error: dateError,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
                onChanged: (value) => setState(() => _date = value),
              ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                label: 'Note',
                controller: _descriptionController,
                hint: isContribution ? 'Payday' : 'Emergency repair',
                helper: 'Optional.',
                error: descriptionError,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_showErrors) setState(() {});
                },
              ),

              if (!isContribution) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: finance.infoSurface,
                    borderRadius: AppRadius.cardAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.info,
                        size: AppIconSize.sm,
                        color: finance.infoText,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Taking money out lowers what this goal holds. '
                          'The movement stays in the history, so the goal '
                          'still shows what happened.',
                          style: AppTypography.caption.copyWith(
                            color: finance.infoText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: isContribution
              ? AppButton.primary(
                  label: 'Add to goal',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : () => _save(progress),
                )
              : AppButton.secondary(
                  label: 'Take out',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : () => _save(progress),
                ),
        ),
      ],
    );
  }
}
