import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../reports/domain/report_period.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/transaction_category.dart';
import '../../domain/budget.dart';
import '../../domain/budget_validator.dart';
import '../providers/budget_providers.dart';

/// Creating a budget, and editing one.
///
/// One screen for both: the fields and the rules are identical, and two
/// would drift. [existing] is null when creating.
///
/// ## Kept to four fields
///
/// Type, amount, category, note. Budgeting is the feature people abandon
/// first, and every extra field is another chance to abandon it — so the
/// month comes from the screen the user was already looking at, and the
/// period is monthly because that is the only one this phase supports.
class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, this.existing, this.initialKind});

  final Budget? existing;

  /// Preselects the type, so "Set a monthly budget" lands on a form that
  /// already knows what the user pressed.
  final BudgetKind? initialKind;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late BudgetKind _kind;
  String? _categoryId;
  String? _categoryLabel;

  int? _minorUnits;
  bool _showErrors = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _kind = existing?.kind ?? widget.initialKind ?? BudgetKind.category;
    _categoryId = existing?.categoryId;
    _categoryLabel = existing?.categoryLabel;
    _minorUnits = existing?.amount.minorUnits;
    _amountController = TextEditingController(
      text: existing == null ? '' : '${existing.amount.minorUnits}',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Switching to an overall budget drops the category, which an overall
  /// budget has no use for and which would otherwise be saved alongside
  /// it and confuse every later read.
  void _onKindChanged(BudgetKind kind) {
    setState(() {
      _kind = kind;
      if (kind == BudgetKind.overall) {
        _categoryId = null;
        _categoryLabel = null;
      }
    });
  }

  Future<void> _save() async {
    // The month's plans are read here rather than taken from the last
    // build: the duplicate rule is the only one that depends on data
    // loaded asynchronously, and a user who presses Create inside that
    // window would otherwise save a second budget for the same category
    // against an empty list.
    final existingBudgets = await ref.read(budgetsForMonthProvider.future);
    if (!mounted) return;

    final canSave = BudgetValidator.canSave(
      kind: _kind,
      minorUnits: _minorUnits,
      categoryId: _categoryId,
      description: _descriptionController.text,
      existing: existingBudgets,
      editingId: widget.existing?.id,
    );

    if (!canSave) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _isSaving = true);

    final actions = ref.read(budgetActionsProvider);
    final month = ref.read(budgetMonthProvider);
    final existing = widget.existing;

    final budget = Budget(
      id: existing?.id ?? actions.newId(),
      kind: _kind,
      amount: Money(_minorUnits!),
      year: existing?.year ?? month.year,
      month: existing?.month ?? month.month,
      categoryId: _categoryId,
      categoryLabel: _categoryLabel,
      description: _descriptionController.text.trim(),
    );

    try {
      if (existing == null) {
        await actions.create(budget);
      } else {
        await actions.update(budget);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, 'Could not save that. $error');
      return;
    }

    if (!mounted) return;
    AppSnackbar.success(
      context,
      _isEditing ? 'Budget updated' : 'Budget created',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final month = ref.watch(budgetMonthProvider);
    final existingBudgets =
        ref.watch(budgetsForMonthProvider).value ?? const <Budget>[];

    final amountError = _showErrors
        ? BudgetValidator.amount(_minorUnits)
        : null;
    final categoryError = _showErrors
        ? BudgetValidator.category(_kind, _categoryId)
        : null;
    final descriptionError = _showErrors
        ? BudgetValidator.description(_descriptionController.text)
        : null;
    final duplicateError = _showErrors
        ? BudgetValidator.duplicate(
            kind: _kind,
            categoryId: _categoryId,
            existing: existingBudgets,
            editingId: widget.existing?.id,
          )
        : null;

    final period = _isEditing
        ? '${ReportPeriod.monthName(widget.existing!.month)} '
              '${widget.existing!.year}'
        : '${ReportPeriod.monthName(month.month)} ${month.year}';

    return Scaffold(
      appBar: AppTopBar(
        title: _isEditing ? 'Edit budget' : 'New budget',
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
                  _KindSelector(value: _kind, onChanged: _onKindChanged),
                  const SizedBox(height: AppSpacing.xl),

                  AmountField(
                    label: 'Budget amount',
                    controller: _amountController,
                    autofocus: !_isEditing,
                    error: amountError,
                    helper: _kind == BudgetKind.overall
                        ? 'The most you plan to spend all month'
                        : 'The most you plan to spend in this category',
                    onChangedMinorUnits: (value) {
                      _minorUnits = value;
                      if (_showErrors) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_kind == BudgetKind.category) ...[
                    _CategoryPicker(
                      selectedId: _categoryId,
                      error: categoryError,
                      onSelected: (category) => setState(() {
                        _categoryId = category.id;
                        _categoryLabel = category.label;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // The month is shown, not chosen: the user came from a
                  // screen already showing a month, and asking them to
                  // pick it again invites choosing the wrong one.
                  _PeriodRow(period: period),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Note',
                    controller: _descriptionController,
                    hint: 'Rent and service charge',
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
            // The duplicate message sits with the button, not in the
            // form.
            //
            // It is the one error that belongs to no single field, and
            // inside the scrolling form it landed below the fold: the
            // user pressed Create budget, nothing appeared to happen,
            // and the explanation was off-screen. Beside the refused
            // action it cannot be missed.
            if (duplicateError != null)
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
                    color: finance.expenseSurface,
                    borderRadius: AppRadius.cardAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.error,
                        size: AppIconSize.sm,
                        color: finance.expenseText,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          duplicateError,
                          style: AppTypography.caption.copyWith(
                            color: finance.expenseText,
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
                label: _isEditing ? 'Save changes' : 'Create budget',
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

/// Overall or one category, as two halves of one control.
class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});

  final BudgetKind value;
  final ValueChanged<BudgetKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What does this cover?',
          style: AppTypography.label.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final kind in BudgetKind.values) ...[
              if (kind != BudgetKind.values.first)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _KindHalf(
                  kind: kind,
                  isSelected: value == kind,
                  onTap: () => onChanged(kind),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _KindHalf extends StatelessWidget {
  const _KindHalf({
    required this.kind,
    required this.isSelected,
    required this.onTap,
  });

  final BudgetKind kind;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final primary = context.colors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: kind == BudgetKind.overall ? 'Whole month' : 'One category',
      excludeSemantics: true,
      child: Material(
        color: isSelected ? finance.infoSurface : finance.surfaceMuted,
        borderRadius: AppRadius.buttonAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.buttonAll,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.buttonAll,
              border: Border.all(
                color: isSelected ? primary : finance.border,
                width: isSelected ? AppStroke.focus : AppStroke.hairline,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
              constraints: const BoxConstraints(
                minHeight: AppSpacing.controlHeight,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    kind == BudgetKind.overall
                        ? AppIcons.budgets
                        : AppIcons.filter,
                    size: AppIconSize.md,
                    color: isSelected ? primary : finance.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // Plainer than the enum's own label: "Overall monthly
                    // budget" is accurate and reads like a form field.
                    kind == BudgetKind.overall ? 'Whole month' : 'One category',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected ? primary : finance.textSecondary,
                    ),
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

/// Expense categories only — income cannot be budgeted.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selectedId,
    required this.onSelected,
    this.error,
  });

  final String? selectedId;
  final ValueChanged<TransactionCategory> onSelected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final categories = TransactionCategories.forType(TransactionType.expense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Category',
              style: AppTypography.label.copyWith(color: finance.textPrimary),
            ),
            Text(
              ' *',
              style: AppTypography.label.copyWith(color: finance.expenseText),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in categories)
              _CategoryChip(
                category: category,
                isSelected: category.id == selectedId,
                onTap: () => onSelected(category),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error!,
            style: AppTypography.caption.copyWith(color: finance.expenseText),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final TransactionCategory category;
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
      label: category.label,
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
                    AppIcons.forCategory(category.id),
                    size: AppIconSize.sm,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    category.label,
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

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period});

  final String period;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period',
          style: AppTypography.label.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          height: AppSpacing.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: finance.surfaceMuted,
            borderRadius: AppRadius.inputAll,
            border: Border.all(color: finance.border),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.calendar,
                size: AppIconSize.md,
                color: finance.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  period,
                  style: AppTypography.bodyLarge.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              Text(
                'Monthly',
                style: AppTypography.caption.copyWith(
                  color: finance.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
