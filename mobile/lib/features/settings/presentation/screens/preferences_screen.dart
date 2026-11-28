import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../onboarding/domain/app_language.dart';
import '../../../onboarding/domain/country.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../domain/app_timezone.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

/// Language, money, place and appearance.
///
/// Four settings that between them decide how every figure and date in
/// the app reads. They sit on one screen because a user changing one of
/// them — moving country, say — usually wants to change the next.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final profile = ref.watch(onboardingControllerProvider).draft;
    final onboarding = ref.read(onboardingControllerProvider.notifier);
    final timezone = ref.watch(timezoneProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Preferences',
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
            AppDropdown<AppLanguage>(
              label: 'Language',
              items: AppLanguage.values,
              value: profile?.language ?? AppLanguage.initial,
              itemLabel: (language) => language.label,
              onChanged: (language) {
                if (language == null) return;
                onboarding.updateLanguage(language);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            // Said here rather than discovered: choosing Kiswahili and
            // watching nothing change would be worse than not offering
            // it, and the choice is still worth recording now so the
            // preference is ready when the strings are.
            const PlaceholderNote(
              message:
                  'The interface is English for now. Your choice is saved, '
                  'and the app will follow it once the translations land.',
            ),
            const SizedBox(height: AppSpacing.xl),

            AppDropdown<Country>(
              label: 'Country',
              items: Country.supported,
              value: profile?.country ?? Country.initial,
              itemLabel: (country) => country.name,
              onChanged: (country) {
                if (country == null) return;
                onboarding.updateCountry(country);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Changing country suggests its currency. You can set the '
              'currency to anything you like below.',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppDropdown<Currency>(
              label: 'Currency',
              items: Currency.supported,
              value: profile?.currency ?? Currency.tzs,
              itemLabel: (currency) => '${currency.code} · ${currency.symbol}',
              onChanged: (currency) {
                if (currency == null) return;
                onboarding.updateCurrency(currency);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Amounts already recorded keep the currency they were '
              'recorded in. Nothing is converted.',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppDropdown<AppTimezone>(
              label: 'Timezone',
              items: AppTimezone.supported,
              value: timezone,
              itemLabel: (zone) => zone.label,
              onChanged: (zone) {
                if (zone == null) return;
                ref.read(timezoneProvider.notifier).select(zone);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Decides when your day ends, which is what "today" and "this '
              'month" are measured against.',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppDropdown<ThemeMode>(
              label: 'Appearance',
              items: ThemeMode.values,
              value: themeMode,
              itemLabel: (mode) => switch (mode) {
                ThemeMode.system => 'Match system',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              onChanged: (mode) {
                if (mode == null) return;
                ref.read(themeModeProvider.notifier).set(mode);
              },
            ),
          ],
        ),
      ),
    );
  }
}
