import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import 'app_button.dart';

/// Modal confirmations.
///
/// ## Destructive actions name what they destroy
///
/// "Are you sure?" gives a user nothing to decide with. These dialogs state
/// the consequence ("This will permanently delete the transaction") and label
/// the button with the verb ("Delete"), not "OK" — so a user skimming only
/// the buttons still understands what is about to happen.
abstract final class AppDialog {
  const AppDialog._();

  /// A confirmation. Returns `true` when confirmed, `false` or `null`
  /// otherwise.
  ///
  /// Set [isDestructive] for anything that deletes or discards: the confirm
  /// button turns red and is placed as the *non-default* action, so an
  /// accidental double-tap on the previous screen cannot confirm it.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final finance = context.finance;

        return AlertDialog(
          icon: icon == null
              ? null
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? finance.expenseSurface
                        : finance.infoSurface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: isDestructive
                        ? finance.expenseText
                        : finance.infoText,
                  ),
                ),
          title: Text(title),
          content: Text(message),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          actions: [
            // Stacked, full-width buttons: on a phone held one-handed, two
            // side-by-side buttons put the destructive one under the thumb.
            Column(
              children: [
                if (isDestructive)
                  AppButton.destructive(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                  )
                else
                  AppButton.primary(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppButton.text(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                  isFullWidth: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// An informational dialog with a single dismiss action.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String dismissLabel = 'Got it',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        actions: [
          AppButton.primary(
            label: dismissLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheets.
///
/// The default surface for any choice or short form on a phone: it opens
/// within thumb reach, where a dialog lands in the middle of the screen and a
/// new route costs a full navigation.
abstract final class AppBottomSheet {
  const AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    bool isScrollControlled = true,
    bool showCloseButton = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      builder: (context) {
        final finance = context.finance;

        return Padding(
          // Leaves room for the keyboard when the sheet holds a form.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: AppTypography.titleSection.copyWith(
                            color: finance.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      AppIconButton(
                        icon: AppIcons.close,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Transient confirmations.
///
/// ## Tone carries meaning, and never alone
///
/// Each variant pairs a colour with an icon and plain wording, so a
/// colour-blind user reads the same message. Snackbars are for outcomes the
/// user does not need to act on; anything requiring a decision belongs in a
/// dialog, and anything that must persist belongs on the screen.
abstract final class AppSnackbar {
  const AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppIcons.success, _Tone.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppIcons.error, _Tone.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppIcons.info, _Tone.info);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    _Tone tone,
  ) {
    final finance = context.finance;

    final accent = switch (tone) {
      _Tone.success => finance.income,
      _Tone.error => finance.expense,
      _Tone.info => context.colors.primary,
    };

    ScaffoldMessenger.of(context)
      // One snackbar at a time: a queue of three stacked confirmations is
      // noise, and the newest message is the relevant one.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: AppIconSize.md, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
          margin: const EdgeInsets.all(AppSpacing.lg),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

enum _Tone { success, error, info }
