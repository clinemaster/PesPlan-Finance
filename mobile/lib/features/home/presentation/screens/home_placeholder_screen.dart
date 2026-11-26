import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../onboarding/presentation/providers/auth_providers.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';

/// Where onboarding lands. A placeholder until Phase 04 builds the dashboard.
///
/// It shows the answers onboarding collected rather than a blank page or a
/// mock dashboard: the former makes a completed flow feel broken, and the
/// latter would put invented balances on screen, which this phase is
/// explicitly not allowed to do.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider).draft;
    final finance = context.finance;
    final name = draft?.name.trim().split(RegExp(r'\s+')).first ?? 'there';

    return Scaffold(
      appBar: AppTopBar(
        title: 'LifePilot Finance',
        subtitle: draft == null ? null : '${draft.country.name} · '
            '${draft.currency.code}',
        actions: [
          AppIconButton(
            icon: AppIcons.settings,
            tooltip: 'Design system showcase',
            onPressed: () => context.go(Routes.showcase),
          ),
          AppIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Sign out',
            onPressed: () async {
              ref.read(onboardingControllerProvider.notifier).reset();
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(label: draft?.name ?? '?', size: AppIconSize.huge),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $name',
                          style: AppTypography.titleScreen.copyWith(
                            color: finance.textPrimary,
                          ),
                        ),
                        if (draft != null)
                          Text(
                            draft.email,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // No action on the empty state: its action button is styled
              // for "add your first thing" and carries a plus icon, which
              // would be the wrong invitation entirely for signing out.
              // That lives in the app bar instead.
              const EmptyState(
                icon: AppIcons.insights,
                title: 'Your dashboard arrives in Phase 04',
                message:
                    'Onboarding is complete and your preferences are set. '
                    'Balances, transactions and budgets are not part of this '
                    'phase, so there is nothing to show here yet.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
