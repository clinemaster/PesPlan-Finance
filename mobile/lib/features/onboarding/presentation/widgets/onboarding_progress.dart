import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';

/// A short segmented progress bar for the onboarding steps.
///
/// Segments rather than a continuous bar because the flow has a small, known
/// number of steps: a user can see at a glance that there are three and that
/// they are on the second, which a percentage cannot tell them. Two of the
/// three steps are a single screenful, so the honest message is "this is
/// nearly over".
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    required this.step,
    required this.totalSteps,
    super.key,
  });

  /// 1-based index of the current step.
  final int step;

  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label: 'Step $step of $totalSteps',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 1; index <= totalSteps; index++) ...[
            if (index > 1) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                height: AppSpacing.xs,
                decoration: BoxDecoration(
                  color: index <= step
                      ? context.colors.primary
                      : finance.border,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.xs),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
