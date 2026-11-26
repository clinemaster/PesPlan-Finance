import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../domain/greeting.dart';
import '../providers/dashboard_providers.dart';

/// Greeting, identity, and the two ways out of the dashboard.
///
/// The greeting is the one piece of warmth on a screen otherwise made of
/// figures, and it is worth the small cost: it tells the user the app knows
/// who they are before any number has to.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final draft = ref.watch(onboardingControllerProvider).draft;
    final now = ref.watch(clockProvider)();

    final fullName = draft?.name.trim() ?? '';
    final firstName = fullName.isEmpty
        ? 'there'
        : fullName.split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // The wave is the only emoji in the app. It earns its place
                // by doing what a second sentence of welcome copy would,
                // in one character.
                //
                // Joined to the name with a non-breaking space: a long
                // greeting wraps to two lines on a narrow phone, and a bare
                // wave stranded on its own line looks like a rendering
                // fault rather than a flourish.
                '${greetingFor(now)}, $firstName\u{00A0}👋',
                style: AppTypography.titleScreen.copyWith(
                  color: finance.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                "Here's your financial overview.",
                style: AppTypography.bodyMedium.copyWith(
                  color: finance.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppIconButton(
          icon: AppIcons.notifications,
          tooltip: 'Notifications',
          // Deliberately inert: Phase 04 ships the entry point, not the
          // feature. A badge here would claim there is something to read.
          onPressed: () => AppDialog.info(
            context,
            title: 'Notifications',
            message:
                'Alerts for budgets, goals and unusual spending arrive in a '
                'later phase. Nothing is waiting for you yet.',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Semantics(
          button: true,
          label: 'Profile and settings',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => context.push(Routes.settings),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              child: AppAvatar(
                label: fullName.isEmpty ? '?' : fullName,
                size: AppSpacing.minTouchTarget,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
