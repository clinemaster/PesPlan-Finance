import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/date_labels.dart';
import '../../domain/transaction.dart';
import '../providers/transaction_providers.dart';

/// Everything recorded about one transaction, plus the two things you can
/// do to it.
///
/// A sheet rather than a screen: it is a glance, usually to check an
/// amount or fix a typo, and a sheet keeps the list visible behind it so
/// the user does not lose their place in a long history.
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({required this.transaction, super.key});

  final Transaction transaction;

  static Future<void> show(BuildContext context, Transaction transaction) =>
      AppBottomSheet.show<void>(
        context,
        title: 'Transaction',
        child: TransactionDetailSheet(transaction: transaction),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final isIncome = transaction.type.isIncome;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CategoryIcon(
              category: transaction.categoryId,
              size: AppIconSize.huge,
              tint: isIncome ? finance.incomeSurface : finance.expenseSurface,
              iconColor: isIncome ? finance.incomeText : finance.expenseText,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The sign already says the direction, but the word
                  // removes any doubt on the one screen where the user is
                  // deciding whether a record is correct.
                  AppBadge(
                    label: transaction.type.label,
                    tone: isIncome ? BadgeTone.income : BadgeTone.expense,
                    icon: isIncome ? AppIcons.income : AppIcons.expense,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MoneyText(transaction.amount, size: MoneySize.large),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        _Row(label: 'Category', value: transaction.categoryLabel),
        const AppDivider(),
        _Row(
          label: 'Description',
          value: transaction.description.trim().isEmpty
              ? 'None'
              : transaction.description,
          isMuted: transaction.description.trim().isEmpty,
        ),
        const AppDivider(),
        _Row(label: 'Date', value: DateLabels.full(transaction.date)),
        const AppDivider(),
        _Row(
          label: 'Currency',
          value: '${transaction.currency.code} · '
              '${transaction.currency.symbol}',
        ),
        const AppDivider(),
        _Row(label: 'Reference', value: transaction.id, isMonospaced: true),
        const SizedBox(height: AppSpacing.xl),

        Row(
          children: [
            Expanded(
              child: AppButton.outlined(
                label: 'Edit',
                icon: AppIcons.edit,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.transactionEdit(transaction.id));
                },
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
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this transaction?',
      message:
          'This transaction will be removed from your transaction history. '
          '${transaction.title} · ${transaction.amount.format()}',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed != true) return;

    await ref.read(transactionActionsProvider).delete(transaction.id);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnackbar.success(context, 'Transaction deleted');
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.isMuted = false,
    this.isMonospaced = false,
  });

  final String label;
  final String value;
  final bool isMuted;
  final bool isMonospaced;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
              style:
                  (isMonospaced
                          ? AppTypography.amountSmall
                          : AppTypography.bodyMedium)
                      .copyWith(
                        color: isMuted
                            ? finance.textTertiary
                            : finance.textPrimary,
                        fontStyle: isMuted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
