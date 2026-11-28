import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/subscription.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

/// The plan, and what the other one would add.
///
/// ## No price, and no payment
///
/// There is no store, no receipt and no entitlement check anywhere in
/// the app. This screen exists so the shape of the offer — what is free,
/// what is paid, and how that reads — can be argued about before anyone
/// builds billing against it. The upgrade button switches a local flag
/// and says so.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final subscription = ref.watch(subscriptionProvider);
    final controller = ref.read(subscriptionProvider.notifier);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Your plan',
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
            PlanCard(subscription: subscription),
            const SizedBox(height: AppSpacing.md),

            const PlaceholderNote(
              message:
                  'Prices are not set and no payment can be taken: there is '
                  'no billing in this build. Switching plans here only '
                  'changes what this app shows you.',
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            if (subscription.isPremium && subscription.renewsOn != null) ...[
              SettingsSection(
                title: 'Your subscription',
                rows: [
                  SettingsRow(
                    title: 'Would renew',
                    value: DateLabels.full(subscription.renewsOn!),
                    icon: AppIcons.calendar,
                  ),
                  SettingsRow(
                    title: 'Manage subscription',
                    subtitle:
                        'Opens the store account that owns the purchase, '
                        'once there is one.',
                    icon: AppIcons.settings,
                    onTap: () => _notYet(
                      context,
                      'Managing a subscription',
                      'Changing or cancelling a plan happens in the app '
                          'store that took the payment. There is no '
                          'purchase to manage yet.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
            ],

            FeatureComparison(
              title: 'What Premium adds',
              features: PlanFeature.upgrades,
            ),
            const SizedBox(height: AppSpacing.md),
            FeatureComparison(
              title: 'On every plan',
              features: PlanFeature.shared,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            if (subscription.isPremium)
              AppButton.outlined(
                label: 'Switch back to Free',
                onPressed: () => _downgrade(context, ref),
              )
            else
              AppButton.primary(
                label: 'Try Premium (review only)',
                icon: AppIcons.success,
                onPressed: () => _upgrade(context, controller),
              ),
            const SizedBox(height: AppSpacing.sm),

            AppButton.text(
              label: 'Restore purchases',
              isFullWidth: true,
              onPressed: () => _notYet(
                context,
                'Restoring purchases',
                'This asks the app store what you have already bought and '
                    'puts it back. With no store and no purchases, there '
                    'is nothing to restore.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'The features listed are a proposal, not a commitment. '
              'Nothing in the app currently checks which plan you are on.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upgrade(
    BuildContext context,
    SubscriptionController controller,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Switch to Premium?',
      message:
          'No payment is taken and no account is charged. This changes a '
          'setting on this phone so the Premium screens can be reviewed.',
      confirmLabel: 'Switch',
      icon: AppIcons.success,
    );
    if (confirmed != true) return;

    controller.upgrade();

    if (!context.mounted) return;
    AppSnackbar.success(context, 'Premium switched on for review');
  }

  Future<void> _downgrade(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Switch back to Free?',
      message: 'Nothing is refunded, because nothing was charged.',
      confirmLabel: 'Switch back',
    );
    if (confirmed != true) return;

    ref.read(subscriptionProvider.notifier).cancel();

    if (!context.mounted) return;
    AppSnackbar.info(context, 'Back on the free plan');
  }

  Future<void> _notYet(
    BuildContext context,
    String title,
    String explanation,
  ) => AppBottomSheet.show<void>(
    context,
    title: title,
    child: Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explanation,
            style: AppTypography.bodyMedium.copyWith(
              color: context.finance.textSecondary,
            ),
          ),
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
