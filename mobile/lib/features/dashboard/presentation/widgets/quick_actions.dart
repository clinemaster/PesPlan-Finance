import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../transactions/domain/transaction.dart';

/// The three things a user opens this app to do.
///
/// Placed high, directly under the summary, because recording a purchase is
/// the habit the whole product depends on — and a habit does not survive
/// being four taps deep. Not a floating button: one would cover the bottom
/// bar or the last transaction row, and three actions do not fit behind one
/// anyway without a second tap to expand.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickAction(
            icon: AppIcons.expense,
            label: 'Add expense',
            tone: _ActionTone.expense,
            onTap: () => context.push(
              Routes.transactionNewOfType(TransactionType.expense.name),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(
          child: _QuickAction(
            icon: AppIcons.income,
            label: 'Add income',
            tone: _ActionTone.income,
            onTap: () => context.push(
              Routes.transactionNewOfType(TransactionType.income.name),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(
          child: _QuickAction(
            icon: AppIcons.voice,
            label: 'By voice',
            tone: _ActionTone.neutral,
            onTap: () => context.push(Routes.addVoice),
          ),
        ),
      ],
    );
  }
}

enum _ActionTone { income, expense, neutral }

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _ActionTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final (surface, foreground) = switch (tone) {
      _ActionTone.income => (finance.incomeSurface, finance.incomeText),
      _ActionTone.expense => (finance.expenseSurface, finance.expenseText),
      _ActionTone.neutral => (finance.surfaceMuted, finance.textSecondary),
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                Container(
                  width: AppSpacing.minTouchTarget,
                  height: AppSpacing.minTouchTarget,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: AppIconSize.md, color: foreground),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
