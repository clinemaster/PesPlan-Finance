import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step 3 — a summary, then in.
///
/// A review step earns its place here because the two screens behind it are
/// gone once onboarding ends: this is the last cheap moment to catch a
/// mistyped name. Each row links back to the step that owns it, so fixing
/// something is one tap rather than a hunt through Settings.
class CompletionScreen extends ConsumerWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final draft = state.draft;
    if (draft == null) return const SizedBox.shrink();

    final finance = context.finance;
    final firstName = draft.name.trim().split(RegExp(r'\s+')).first;

    return OnboardingScaffold(
      step: 3,
      totalSteps: 3,
      title: 'You are all set, $firstName',
      subtitle: 'Here is what we have. Change anything that is not right.',
      onBack: () => context.go(Routes.onboardingPreferences),
      footer: AppButton.primary(
        label: 'Start using LifePilot',
        icon: AppIcons.forward,
        // Marking onboarding complete is the whole action. The router's
        // guard notices and moves to the app, which keeps the "where do I go
        // next" decision in one place instead of two.
        onPressed: () =>
            ref.read(onboardingControllerProvider.notifier).complete(),
      ),
      children: [
        Center(
          child: Container(
            width: AppIconSize.huge * 1.5,
            height: AppIconSize.huge * 1.5,
            decoration: BoxDecoration(
              color: finance.successSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.success,
              size: AppIconSize.huge,
              color: finance.successText,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              _SummaryRow(
                icon: AppIcons.profile,
                label: 'Name',
                value: draft.name,
                onEdit: () => context.go(Routes.onboardingProfile),
              ),
              const AppDivider(),
              _SummaryRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: draft.email,
                // No edit affordance: the provider owns this one, and
                // offering a tap that cannot change it would be a lie.
              ),
              const AppDivider(),
              _SummaryRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: draft.hasPhone ? draft.phone! : 'Not added',
                isMuted: !draft.hasPhone,
                onEdit: () => context.go(Routes.onboardingProfile),
              ),
              const AppDivider(),
              _SummaryRow(
                icon: Icons.public_rounded,
                label: 'Country',
                value: draft.country.name,
                onEdit: () => context.go(Routes.onboardingPreferences),
              ),
              const AppDivider(),
              _SummaryRow(
                icon: AppIcons.currency,
                label: 'Currency',
                value: '${draft.currency.code} · ${draft.currency.symbol}',
                onEdit: () => context.go(Routes.onboardingPreferences),
              ),
              const AppDivider(),
              _SummaryRow(
                icon: Icons.translate_rounded,
                label: 'Language',
                value: draft.language.label,
                onEdit: () => context.go(Routes.onboardingPreferences),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
    this.isMuted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  /// Dims the value where it stands for an absent optional answer, so
  /// "Not added" does not read with the same weight as a real one.
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: finance.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTypography.bodyLarge.copyWith(
                    color: isMuted ? finance.textTertiary : finance.textPrimary,
                    fontStyle: isMuted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            AppIconButton(
              icon: AppIcons.edit,
              tooltip: 'Edit $label',
              size: AppIconSize.md,
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}
