import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../widgets/settings_widgets.dart';

/// How you get in, what is kept, and how to leave.
///
/// ## Security and privacy on one screen
///
/// They are the same question from two sides — who can see this, and
/// what is there to see — and splitting them means a user looking for
/// "delete my account" has two places to guess between.
class SecurityPrivacyScreen extends ConsumerWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final profile = ref.watch(onboardingControllerProvider).draft;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Security & privacy',
        showBack: true,
        onBack: () => leaveSettings(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            SettingsSection(
              title: 'Signing in',
              subtitle: 'LifePilot uses your Google account.',
              rows: [
                SettingsRow(
                  title: 'Signed in as',
                  subtitle: profile?.email ?? 'Not signed in',
                  icon: AppIcons.profile,
                ),
                SettingsRow(
                  title: 'No password to remember',
                  subtitle:
                      'There is no LifePilot password — Google handles who '
                      'you are, so there is nothing here to lose or reuse.',
                  icon: AppIcons.insurance,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Locking the app',
              rows: [
                SettingsRow(
                  title: 'Require unlock to open',
                  subtitle:
                      'A screen lock in front of your figures, for a shared '
                      'phone.',
                  icon: AppIcons.hidden,
                  // Switched off and inert on purpose: a lock that looks
                  // enabled and does not lock is worse than none at all.
                  trailing: Switch.adaptive(value: false, onChanged: null),
                ),
                SettingsRow(
                  title: 'Use fingerprint or face',
                  subtitle: 'Unlock with whatever this phone already uses.',
                  icon: AppIcons.success,
                  trailing: Switch.adaptive(value: false, onChanged: null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const PlaceholderNote(
              message:
                  'Both of these are switched off and cannot be turned on '
                  'yet — the lock itself arrives with the account service. '
                  'They are here so the setting is where it will be.',
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Your data',
              subtitle: 'What LifePilot holds, and where it is.',
              rows: [
                SettingsRow(
                  title: 'Everything stays on this phone',
                  subtitle:
                      'Transactions, budgets, goals and conversations are '
                      'stored on this device. No server has them, because '
                      'there is no server yet.',
                  icon: AppIcons.hidden,
                ),
                SettingsRow(
                  title: 'Export your data',
                  subtitle: 'A copy of everything you have recorded.',
                  icon: AppIcons.download,
                  onTap: () => _export(context),
                ),
                SettingsRow(
                  title: 'Privacy policy',
                  icon: AppIcons.info,
                  onTap: () => _policy(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Leaving',
              rows: [
                SettingsRow(
                  title: 'Delete account',
                  subtitle:
                      'Removes your profile and everything recorded against '
                      'it.',
                  icon: AppIcons.delete,
                  isDestructive: true,
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Deleting is permanent once the account service is live. In '
              'this build nothing is removed — the screen is here so the '
              'wording and the confirmation can be reviewed first.',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) => AppBottomSheet.show<void>(
    context,
    title: 'Export your data',
    child: const _Placeholder(
      lines: [
        'This will produce a file holding every transaction, budget, '
            'savings goal and assistant conversation on this device.',
        'The export itself is built with the account service. Nothing is '
            'written or sent today.',
      ],
    ),
  );

  Future<void> _policy(BuildContext context) => AppBottomSheet.show<void>(
    context,
    title: 'Privacy policy',
    child: const _Placeholder(
      lines: [
        'The policy is written alongside the account service, and will '
            'open here when it exists.',
        'What is true today: everything you record stays on this phone, '
            'nothing is uploaded, and no third party receives any of it.',
      ],
    ),
  );

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete your account?',
      message:
          'This would remove your profile and every transaction, budget, '
          'goal and conversation recorded against it. It cannot be undone.',
      confirmLabel: 'Delete account',
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed != true || !context.mounted) return;

    // Confirmed, and still nothing is deleted. The confirmation is the
    // part being reviewed; the deletion needs an account service to
    // delete from, and pretending otherwise would be a lie about
    // someone's data.
    await AppBottomSheet.show<void>(
      context,
      title: 'Nothing was deleted',
      child: const _Placeholder(
        lines: [
          'You confirmed, and on purpose nothing happened: this build has '
              'no account service to delete from, and faking it would '
              'leave your data here while telling you it had gone.',
          'When deletion is real it will remove everything named in the '
              'confirmation, and sign you out on the spot.',
        ],
      ),
    );
  }
}

/// A sheet that says what a control will do, and that it does not do it
/// yet.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          Text(
            line,
            style: AppTypography.bodyMedium.copyWith(
              color: finance.textSecondary,
            ),
          ),
          if (line != lines.last) const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
