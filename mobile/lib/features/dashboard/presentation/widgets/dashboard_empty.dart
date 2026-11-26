import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';

/// What a brand-new account sees.
///
/// ## Why not a dashboard full of zeroes
///
/// Rendering the normal layout with TSh 0 in every card states six
/// financial facts the app has no basis for, and it looks broken rather
/// than new. Worse, a zeroed budget bar reads as "you have spent nothing of
/// your budget" when the truth is "you have no budget".
///
/// So the empty state replaces the dashboard rather than filling it in, and
/// offers the one action that turns it into a real one.
class DashboardEmpty extends StatelessWidget {
  const DashboardEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Container(
            width: AppIconSize.huge * 1.6,
            height: AppIconSize.huge * 1.6,
            decoration: BoxDecoration(
              color: finance.infoSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.insights,
              size: AppIconSize.huge,
              color: finance.infoText,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Your money journey starts here.',
          textAlign: TextAlign.center,
          style: AppTypography.titleSection.copyWith(
            color: finance.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Record your first income or expense to see your financial '
          'overview.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: finance.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        AppButton.primary(
          label: 'Add your first expense',
          icon: AppIcons.add,
          onPressed: () => context.push(Routes.addExpense),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.text(
          label: 'Add income instead',
          isFullWidth: true,
          onPressed: () => context.push(Routes.addIncome),
        ),
      ],
    );
  }
}
