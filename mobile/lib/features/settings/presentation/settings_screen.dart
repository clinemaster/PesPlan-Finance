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
import 'providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Everything about the account, in one place.
///
/// ## A hub, not a pile
///
/// Seven sections, each a row that opens one screen. The alternative —
/// every switch in the app on one scrolling page — is how a settings
/// screen becomes the place nobody can find anything. It is also why the
/// rows carry their current value: someone checking which currency they
/// are on should not have to open a screen to find out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final profile = ref.watch(onboardingControllerProvider).draft;
    final themeMode = ref.watch(themeModeProvider);
    final notifications = ref.watch(notificationPreferencesProvider);
    final subscription = ref.watch(subscriptionProvider);
    final dataMode = ref.watch(mockDataModeProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Profile & settings',
        showBack: true,
        onBack: () => leaveSettings(context, fallback: Routes.home),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            if (profile != null)
              AppCard(
                onTap: () => context.push(Routes.settingsProfile),
                child: Row(
                  children: [
                    AppAvatar(label: profile.name, size: AppIconSize.huge),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleCard.copyWith(
                              color: finance.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            profile.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: finance.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              AppBadge(
                                label: subscription.plan.label,
                                tone: subscription.isPremium
                                    ? BadgeTone.income
                                    : BadgeTone.neutral,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  '${profile.country.name} · '
                                  '${profile.currency.code}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: finance.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: AppIconSize.md,
                      color: finance.textTertiary,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Preferences',
              rows: [
                SettingsRow(
                  title: 'Language, currency and region',
                  icon: AppIcons.settings,
                  value:
                      '${profile?.language.label ?? 'English'} · '
                      '${profile?.currency.code ?? 'TZS'}',
                  onTap: () => context.push(Routes.settingsPreferences),
                ),
                SettingsRow(
                  title: 'Appearance',
                  icon: AppIcons.visible,
                  value: switch (themeMode) {
                    ThemeMode.system => 'Match system',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  onTap: () => context.push(Routes.settingsPreferences),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Notifications',
              rows: [
                SettingsRow(
                  title: 'Alerts and reminders',
                  icon: AppIcons.notifications,
                  value: notifications.summary,
                  onTap: () => context.push(Routes.settingsNotifications),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Security & privacy',
              rows: [
                SettingsRow(
                  title: 'Security',
                  subtitle: 'How you sign in, and what protects this app.',
                  icon: AppIcons.insurance,
                  onTap: () => context.push(Routes.settingsPrivacy),
                ),
                SettingsRow(
                  title: 'Your data',
                  subtitle: 'What is kept, where it goes, and how to leave.',
                  icon: AppIcons.download,
                  onTap: () => context.push(Routes.settingsPrivacy),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Subscription',
              rows: [
                SettingsRow(
                  title: 'Your plan',
                  subtitle: subscription.isPremium
                      ? 'Premium, switched on for review'
                      : 'Free — see what Premium adds',
                  icon: AppIcons.success,
                  value: subscription.plan.label,
                  onTap: () => context.push(Routes.settingsSubscription),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Help & support',
              rows: [
                SettingsRow(
                  title: 'Help, contact and legal',
                  icon: AppIcons.info,
                  onTap: () => context.push(Routes.settingsHelp),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ------------------------------------------------ review only
            SectionHeader(
              title: 'Review controls',
              subtitle: 'Development aids. These go away with the mock data.',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPadding,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  SettingsRow(
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
                  SettingsRow(
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
                  SettingsRow(
                    title: 'Design system showcase',
                    onTap: () => context.go(Routes.showcase),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Account',
              rows: [
                SettingsRow(
                  title: 'Sign out',
                  icon: Icons.logout_rounded,
                  onTap: () => _signOut(context, ref),
                ),
                SettingsRow(
                  title: 'Delete account',
                  subtitle: 'Removes your account and everything in it.',
                  icon: AppIcons.delete,
                  isDestructive: true,
                  onTap: () => context.push(Routes.settingsPrivacy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Sign out?',
      message:
          'Your transactions, budgets and goals stay on this device. You '
          'will set up again the next time you sign in.',
      confirmLabel: 'Sign out',
    );
    if (confirmed != true) return;

    ref.read(onboardingControllerProvider.notifier).reset();
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
