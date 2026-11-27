import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/savings_goal.dart';
import '../../domain/savings_validator.dart';
import '../providers/savings_providers.dart';
import '../widgets/savings_widgets.dart';

/// Creating a goal, and editing one.
///
/// One screen for both: the fields and the rules are the same, and two
/// would drift. [existing] is null when creating.
///
/// ## Five fields, two of them optional
///
/// Name, target, picture — then a date and a note the user may skip.
/// Saving is the thing people mean to start and never do; every extra
/// required field is another reason this never gets finished.
class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.existing});

  final SavingsGoal? existing;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _initialController;
  late final TextEditingController _descriptionController;

  late String _iconKey;
  DateTime? _targetDate;

  int? _targetMinorUnits;
  int? _initialMinorUnits;
  bool _showErrors = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _iconKey = existing?.iconKey ?? GoalIcon.fallback;
    _targetDate = existing?.targetDate;
    _targetMinorUnits = existing?.target.minorUnits;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetController = TextEditingController(
      text: existing == null ? '' : '${existing.target.minorUnits}',
    );
    _initialController = TextEditingController();
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final now = ref.read(clockProvider)();

    final canSave = SavingsValidator.canSaveGoal(
      name: _nameController.text,
      targetMinorUnits: _targetMinorUnits,
      initialMinorUnits: _initialMinorUnits,
      description: _descriptionController.text,
      targetDate: _targetDate,
      now: now,
      isEditing: _isEditing,
    );

    if (!canSave) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _isSaving = true);

    final actions = ref.read(savingsActionsProvider);
    final existing = widget.existing;

    final goal = SavingsGoal(
      id: existing?.id ?? actions.newId(),
      name: _nameController.text.trim(),
      target: Money(_targetMinorUnits!),
      createdAt: existing?.createdAt ?? now,
      iconKey: _iconKey,
      targetDate: _targetDate,
      description: _descriptionController.text.trim(),
    );

    try {
      if (existing == null) {
        await actions.create(goal, initialMinorUnits: _initialMinorUnits ?? 0);
      } else {
        await actions.update(goal);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, 'Could not save that. $error');
      return;
    }

    if (!mounted) return;
    AppSnackbar.success(context, _isEditing ? 'Goal updated' : 'Goal created');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final now = ref.watch(clockProvider)();

    final nameError = _showErrors
        ? SavingsValidator.name(_nameController.text)
        : null;
    final targetError = _showErrors
        ? SavingsValidator.target(_targetMinorUnits)
        : null;
    final initialError = _showErrors && !_isEditing
        ? SavingsValidator.initialAmount(_initialMinorUnits, _targetMinorUnits)
        : null;
    final dateError = _showErrors
        ? SavingsValidator.targetDate(_targetDate, now)
        : null;
    final descriptionError = _showErrors
        ? SavingsValidator.description(_descriptionController.text)
        : null;

    // Lowering a target below what is already saved finishes the goal.
    // Said plainly before it happens, because a user who meant to correct
    // a typo should not be surprised by a completion.
    final completesOnSave =
        _isEditing &&
        _targetMinorUnits != null &&
        _targetMinorUnits! > 0 &&
        (ref
                    .watch(goalProgressProvider(widget.existing!.id))
                    .value
                    ?.saved
                    .minorUnits ??
                0) >=
            _targetMinorUnits!;

    return Scaffold(
      appBar: AppTopBar(
        title: _isEditing ? 'Edit goal' : 'New goal',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: Column(
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
                  AppTextField(
                    label: 'Goal name',
                    controller: _nameController,
                    hint: 'Emergency fund',
                    autofocus: !_isEditing,
                    error: nameError,
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AmountField(
                    label: 'Target amount',
                    controller: _targetController,
                    error: targetError,
                    helper: 'How much you want to have put aside',
                    onChangedMinorUnits: (value) {
                      _targetMinorUnits = value;
                      if (_showErrors) setState(() {});
                      // The completion warning depends on this figure, so
                      // the field drives a rebuild while editing.
                      if (_isEditing) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Only on creation. An existing goal's balance is its
                  // movements, and an "amount" box on the edit form would
                  // look like a way to overwrite them.
                  if (!_isEditing) ...[
                    AmountField(
                      label: 'Already saved',
                      controller: _initialController,
                      error: initialError,
                      helper:
                          'Optional. What you have put aside for this '
                          'already.',
                      onChangedMinorUnits: (value) {
                        _initialMinorUnits = value;
                        if (_showErrors) setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  GoalIconPicker(
                    selectedKey: _iconKey,
                    onSelected: (icon) => setState(() => _iconKey = icon.key),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  DateField(
                    label: 'Target date',
                    hint: 'Optional',
                    value: _targetDate == null
                        ? null
                        : DateLabels.full(_targetDate!),
                    error: dateError,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(
                      now.year + SavingsValidator.maxYearsAhead,
                      now.month,
                      now.day,
                    ),
                    onChanged: (date) => setState(() => _targetDate = date),
                  ),
                  if (_targetDate != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton.text(
                        label: 'Clear date',
                        icon: AppIcons.close,
                        onPressed: () => setState(() => _targetDate = null),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Note',
                    controller: _descriptionController,
                    hint: 'Three months of essentials',
                    helper: 'Optional.',
                    error: descriptionError,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                  ),
                ],
              ),
            ),

            if (completesOnSave)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  0,
                ),
                child: Container(
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
                          'You have already saved this much. Saving this '
                          'target will mark the goal complete. Your history '
                          'is kept.',
                          style: AppTypography.caption.copyWith(
                            color: finance.successText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: AppButton.primary(
                label: _isEditing ? 'Save changes' : 'Create goal',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
