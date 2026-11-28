import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/notification_preferences.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

/// What the app would tell you about, and when.
///
/// Grouped by what the message is for rather than by how it is
/// delivered: a user deciding whether to hear about budgets is making a
/// decision about their money, not about a channel.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Notifications',
        showBack: true,
        onBack: () => leaveSettings(context),
        actions: [
          AppButton.text(
            label: preferences.allOff ? 'All on' : 'All off',
            size: AppButtonSize.small,
            onPressed: () => controller.setAll(isOn: preferences.allOff),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
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
            const PlaceholderNote(
              message:
                  'Nothing is sent yet — there is no notification service in '
                  'this build. Your choices are saved and will be honoured '
                  'the day there is one.',
              icon: AppIcons.notifications,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            for (final group in NotificationGroup.values) ...[
              SettingsSection(
                title: group.title,
                subtitle: group.subtitle,
                rows: [
                  for (final channel in group.channels)
                    SettingsRow(
                      title: channel.title,
                      subtitle: channel.description,
                      trailing: Switch.adaptive(
                        value: preferences.isOn(channel),
                        onChanged: (isOn) =>
                            controller.set(channel, isOn: isOn),
                      ),
                    ),
                ],
              ),
              if (group != NotificationGroup.values.last)
                const SizedBox(height: AppSpacing.sectionGap),
            ],
          ],
        ),
      ),
    );
  }
}
