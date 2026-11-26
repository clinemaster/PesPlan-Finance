import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/time/clock.dart';
import '../../domain/date_labels.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_category.dart';
import '../../domain/transaction_validator.dart';
import '../providers/transaction_providers.dart';
import '../widgets/category_picker.dart';

/// Recording a transaction, and editing one.
///
/// One screen for both, because the fields and the rules are identical and
/// two screens would drift. [existing] is null when adding.
///
/// ## The amount comes first and stays first
///
/// It is the only field the user definitely knows when they open this
/// screen — they have just paid for something — so it is at the top, large,
/// and focused on arrival. Everything beneath it either has a sensible
/// default (today) or is one tap (category).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.existing, this.initialType});

  /// The transaction being edited, or null when adding a new one.
  final Transaction? existing;

  /// Preselects a side of the ledger. The dashboard's two quick actions
  /// use it so "Add income" does not land on an expense form.
  final TransactionType? initialType;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late TransactionType _type;
  String? _categoryId;
  String? _categoryLabel;
  late DateTime _date;

  int? _minorUnits;
  bool _showErrors = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _type = existing?.type ?? widget.initialType ?? TransactionType.expense;
    _categoryId = existing?.categoryId;
    _categoryLabel = existing?.categoryLabel;
    _date = existing?.date ?? ref.read(clockProvider)();

    // Seeded as a magnitude: the form asks "how much", and the sign is the
    // type selector's job.
    _minorUnits = existing?.amount.minorUnits.abs();
    _amountController = TextEditingController(
      text: existing == null ? '' : _minorUnits.toString(),
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

  /// Switching side clears a category that does not exist on the new side.
  ///
  /// Keeping "Salary" selected after switching to Expense would save a
  /// transaction filed under a category its own type does not offer.
  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      final id = _categoryId;
      if (id != null && TransactionCategories.find(id, type) == null) {
        _categoryId = null;
        _categoryLabel = null;
      } else if (id != null) {
        _categoryLabel = TransactionCategories.find(id, type)!.label;
      }
    });
  }

  Future<void> _save() async {
    final today = ref.read(clockProvider)();

    final canSave = TransactionValidator.canSave(
      minorUnits: _minorUnits,
      categoryId: _categoryId,
      date: _date,
      description: _descriptionController.text,
      today: today,
    );

    if (!canSave) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _isSaving = true);

    final actions = ref.read(transactionActionsProvider);
    final existing = widget.existing;

    final transaction = Transaction.create(
      id: existing?.id ?? actions.newId(),
      type: _type,
      magnitudeMinorUnits: _minorUnits!,
      categoryId: _categoryId!,
      categoryLabel: _categoryLabel!,
      description: _descriptionController.text.trim(),
      date: _date,
      createdAt: existing?.createdAt ?? today,
    );

    try {
      if (existing == null) {
        await actions.add(transaction);
      } else {
        await actions.update(transaction);
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
      _isEditing ? 'Transaction updated' : 'Transaction saved',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final today = ref.watch(clockProvider)();

    final amountError = _showErrors
        ? TransactionValidator.amount(_minorUnits)
        : null;
    final categoryError = _showErrors
        ? TransactionValidator.category(_categoryId)
        : null;
    final dateError = _showErrors
        ? TransactionValidator.date(_date, today: today)
        : null;
    final descriptionError = _showErrors
        ? TransactionValidator.description(_descriptionController.text)
        : null;

    return Scaffold(
      appBar: AppTopBar(
        title: _isEditing ? 'Edit transaction' : 'New transaction',
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
                  TransactionTypeSelector(
                    value: _type,
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AmountField(
                    label: 'Amount',
                    controller: _amountController,
                    autofocus: !_isEditing,
                    error: amountError,
                    helper: _type.isIncome
                        ? 'How much came in'
                        : 'How much went out',
                    onChangedMinorUnits: (value) {
                      _minorUnits = value;
                      if (_showErrors) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  CategoryPicker(
                    type: _type,
                    selectedId: _categoryId,
                    error: categoryError,
                    onSelected: (category) => setState(() {
                      _categoryId = category.id;
                      _categoryLabel = category.label;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  DateField(
                    label: 'Date',
                    value: DateLabels.full(_date),
                    error: dateError,
                    lastDate: today,
                    onChanged: (picked) => setState(() => _date = picked),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Description',
                    controller: _descriptionController,
                    // Generic examples on purpose: a hint that reads like
                    // a real entry is mistaken for one, both by a user
                    // glancing at a pre-filled edit form and by a test.
                    hint: _type.isIncome
                        ? 'Salary, sale, gift'
                        : 'Lunch, bus fare, airtime',
                    helper: 'Optional. Helps you find it later.',
                    error: descriptionError,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'Saved on this device only. Nothing is sent anywhere '
                    'in this phase.',
                    style: AppTypography.caption.copyWith(
                      color: finance.textTertiary,
                    ),
                  ),
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
              child: AppButton.primary(
                label: _isEditing ? 'Save changes' : 'Save transaction',
                isLoading: _isSaving,
                // Never disabled on an incomplete form: a dead button
                // explains nothing, where a press that reveals what is
                // missing does.
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
