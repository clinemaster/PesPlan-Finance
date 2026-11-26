import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import 'onboarding_progress.dart';

/// The shared frame for every onboarding step.
///
/// Each step is a title, a short explanation, some fields and one primary
/// action. Giving them one frame keeps the spacing, the progress indicator
/// and the footer identical between screens, so moving forward feels like
/// the same page updating rather than three different pages.
///
/// The footer is pinned rather than scrolled with the content: the primary
/// action should never be somewhere the user has to go looking for it, and
/// on a short screen a scrolled button can sit just below the fold where it
/// looks like there is nothing to do.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.children,
    required this.footer,
    super.key,
    this.subtitle,
    this.onBack,
    this.backTooltip = 'Back',
  });

  final String title;
  final String? subtitle;
  final int step;
  final int totalSteps;

  /// The body, laid out in a column and scrollable when it overflows —
  /// which it will on a small screen with the keyboard open.
  final List<Widget> children;

  /// The pinned action area, usually one [AppButton] and sometimes a text
  /// button beneath it.
  final Widget footer;

  /// Null hides the back affordance. A step that cannot be reversed should
  /// say so by not offering the control, rather than offering one that does
  /// nothing.
  final VoidCallback? onBack;

  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : AppIconButton(
                icon: AppIcons.back,
                tooltip: backTooltip,
                onPressed: onBack,
              ),
        automaticallyImplyLeading: false,
        title: OnboardingProgress(step: step, totalSteps: totalSteps),
        titleSpacing: 0,
        // The progress bar is the title, so it needs the horizontal inset
        // the title would otherwise have supplied.
        actions: const [SizedBox(width: AppSpacing.lg)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleScreen.copyWith(
                        color: finance.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        subtitle!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: finance.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}
