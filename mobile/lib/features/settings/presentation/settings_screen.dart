import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/router/routes.dart';
import '../../assistant/presentation/providers/assistant_providers.dart';
import '../../dashboard/data/mock_dashboard_repository.dart';
import '../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../onboarding/presentation/providers/auth_providers.dart';
import '../../onboarding/presentation/providers/onboarding_providers.dart';

/// Profile, appearance, and the controls a reviewer needs.
///
/// Pushed over the shell rather than given a tab: it is somewhere you go and
/// come back from, not a place you work.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final draft = ref.watch(onboardingControllerProvider).draft;
    final themeMode = ref.watch(themeModeProvider);
    final dataMode = ref.watch(mockDataModeProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Profile & settings',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            if (draft != null)
              AppCard(
                child: Row(
                  children: [
                    AppAvatar(label: draft.name, size: AppIconSize.huge),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.name,
                            style: AppTypography.titleCard.copyWith(
                              color: finance.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            draft.email,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${draft.country.name} · ${draft.currency.code} · '
                            '${draft.language.label}',
                            style: AppTypography.caption.copyWith(
                              color: finance.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sectionGap),

            SectionHeader(title: 'Appearance', padding: EdgeInsets.zero),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: AppDropdown<ThemeMode>(
                label: 'Theme',
                items: ThemeMode.values,
                value: themeMode,
                itemLabel: (mode) => switch (mode) {
                  ThemeMode.system => 'Match system',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                },
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).set(mode);
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ------------------------------------------------ review only
            SectionHeader(
              title: 'Review controls',
              subtitle: 'Development aids. These go away with the mock data.',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.md),
            // Plain rows rather than ListTile: ListTile paints its
            // background and ripple on the nearest Material ancestor, and
            // AppCard's own decorated background sits in between — so the
            // splash would be drawn underneath the card and never seen.
            AppCard(
              child: Column(
                children: [
                  _SettingRow(
                    title: 'Show the empty dashboard',
                    subtitle: 'Reports an account with nothing recorded yet.',
                    trailing: Switch.adaptive(
                      value: dataMode == MockDataMode.empty,
                      onChanged: (isEmpty) => ref
                          .read(mockDataModeProvider.notifier)
                          .select(
                            isEmpty
                                ? MockDataMode.empty
                                : MockDataMode.populated,
                          ),
                    ),
                  ),
                  const AppDivider(),
                  _SettingRow(
                    title: 'Make the assistant fail',
                    subtitle:
                        'The next question comes back as an error, so the '
                        'retry path can be seen.',
                    trailing: Switch.adaptive(
                      value: ref.watch(assistantShouldFailProvider),
                      onChanged: (shouldFail) => ref
                          .read(assistantShouldFailProvider.notifier)
                          .set(shouldFail: shouldFail),
                    ),
                  ),
                  const AppDivider(),
                  _SettingRow(
                    title: 'Design system showcase',
                    onTap: () => context.go(Routes.showcase),
                    trailing: Icon(
                      AppIcons.chevronRight,
                      color: finance.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            AppButton.outlined(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirmed = await AppDialog.confirm(
                  context,
                  title: 'Sign out?',
                  message:
                      'Nothing is stored on this device yet, so you will '
                      'start setup again next time.',
                  confirmLabel: 'Sign out',
                );
                if (confirmed != true) return;

                ref.read(onboardingControllerProvider.notifier).reset();
                await ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One row inside a settings card.
///
/// Exists because [ListTile] cannot be used here: it paints its background
/// and ink on the nearest [Material], which is behind [AppCard]'s own
/// decorated surface, so the ripple would be invisible.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;

  /// Null for a row whose control is the trailing widget itself.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: content,
      ),
    );
  }
}
