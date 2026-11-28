import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../widgets/settings_widgets.dart';

/// Where to go when the app is not enough.
///
/// Every row here opens a sheet saying what it will do and that it does
/// not do it yet. A help centre link that goes nowhere is the oldest
/// broken promise in software; saying so costs a sentence.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  /// Kept beside `pubspec.yaml`'s version by hand.
  ///
  /// Reading the real one needs a plugin and a platform channel, which
  /// is more machinery than a line of text is worth before there is a
  /// release to track.
  static const String appVersion = '1.0.0 (build 1)';

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Help & support',
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
              title: 'Getting help',
              rows: [
                SettingsRow(
                  title: 'Help centre',
                  subtitle: 'Guides for everything in the app.',
                  icon: AppIcons.info,
                  onTap: () => _sheet(
                    context,
                    'Help centre',
                    'Written guides live on the web, and this opens them. '
                        'They are written alongside the public release.',
                  ),
                ),
                SettingsRow(
                  title: 'Common questions',
                  subtitle: 'The things people ask first.',
                  icon: AppIcons.assistant,
                  onTap: () => _sheet(
                    context,
                    'Common questions',
                    'A short list of answers — how budgets are measured, '
                        'why the net is not a balance, what the assistant '
                        'can see. It arrives with the help centre.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Getting in touch',
              rows: [
                SettingsRow(
                  title: 'Contact support',
                  subtitle: 'A person, for anything the guides do not cover.',
                  icon: AppIcons.profile,
                  onTap: () => _sheet(
                    context,
                    'Contact support',
                    'This opens a message to the support team with your app '
                        'version attached — and nothing else, unless you '
                        'add it. There is no inbox behind it yet.',
                  ),
                ),
                SettingsRow(
                  title: 'Send feedback',
                  subtitle: 'Tell us what is wrong, or what is missing.',
                  icon: AppIcons.edit,
                  onTap: () => _sheet(
                    context,
                    'Send feedback',
                    'Somewhere to say what is not working without filing it '
                        'as a support request. The route to the team is '
                        'built with the backend.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            SettingsSection(
              title: 'Legal',
              rows: [
                SettingsRow(
                  title: 'Terms of service',
                  icon: AppIcons.transactions,
                  onTap: () => _sheet(
                    context,
                    'Terms of service',
                    'The terms are written before the public release, and '
                        'will open here.',
                  ),
                ),
                SettingsRow(
                  title: 'Privacy policy',
                  icon: AppIcons.insurance,
                  onTap: () => _sheet(
                    context,
                    'Privacy policy',
                    'What is true today: everything you record stays on '
                        'this phone, nothing is uploaded, and no third '
                        'party receives any of it.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            AppCard(
              child: Column(
                children: [
                  Text(
                    'LifePilot Finance',
                    style: AppTypography.titleCard.copyWith(
                      color: finance.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Version $appVersion',
                    style: AppTypography.bodySmall.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your money, made simple.',
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
    );
  }

  Future<void> _sheet(BuildContext context, String title, String body) =>
      AppBottomSheet.show<void>(
        context,
        title: title,
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.finance.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const PlaceholderNote(message: 'Not wired up in this build.'),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
}
