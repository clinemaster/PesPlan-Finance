import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/app_language.dart';
import '../../domain/country.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step 2 — where the user is and what they want to see.
///
/// Every field here already holds a sensible answer, so a user who agrees
/// with all three can continue without touching anything. That is deliberate:
/// the screen exists to let people disagree, not to make them choose.
class PreferencesSetupScreen extends ConsumerWidget {
  const PreferencesSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider).draft;
    if (draft == null) return const SizedBox.shrink();

    final controller = ref.read(onboardingControllerProvider.notifier);
    final finance = context.finance;

    return OnboardingScaffold(
      step: 2,
      totalSteps: 3,
      title: 'Your preferences',
      subtitle: 'These shape how amounts and dates appear. You can change '
          'them later in Settings.',
      onBack: () => context.go(Routes.onboardingProfile),
      footer: AppButton.primary(
        label: 'Continue',
        onPressed: () => context.go(Routes.onboardingComplete),
      ),
      children: [
        AppDropdown<Country>(
          label: 'Country',
          items: Country.supported,
          value: draft.country,
          itemLabel: (country) => country.name,
          onChanged: (country) {
            if (country != null) controller.updateCountry(country);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sets your currency to match. Change it below if you budget in '
          'something else.',
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xl),

        CurrencyField(
          value: draft.currency,
          onChanged: (currency) {
            if (currency != null) controller.updateCurrency(currency);
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        AppDropdown<AppLanguage>(
          label: 'Language',
          items: AppLanguage.values,
          value: draft.language,
          itemLabel: (language) => language.label,
          onChanged: (language) {
            if (language != null) controller.updateLanguage(language);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Saved as a preference. The interface is English only for now — '
          'Kiswahili arrives with translation in a later release.',
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
      ],
    );
  }
}
