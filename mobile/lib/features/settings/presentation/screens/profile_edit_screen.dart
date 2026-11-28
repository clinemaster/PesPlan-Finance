import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../onboarding/domain/country.dart';
import '../../../onboarding/domain/profile_validator.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../widgets/settings_widgets.dart';

/// The details the user gave at setup, changeable afterwards.
///
/// ## Email is shown and not edited
///
/// It comes from the identity provider, and changing it here would
/// either be a lie or an account migration. It is displayed because
/// people check which account they are signed in to far more often than
/// they change anything on this screen.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late Country _country;

  bool _showErrors = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(onboardingControllerProvider).draft;

    _name = TextEditingController(text: profile?.name ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _country = profile?.country ?? Country.initial;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameError = ProfileValidator.name(_name.text);
    final phoneError = ProfileValidator.phone(_phone.text);

    if (nameError != null || phoneError != null) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _isSaving = true);

    final controller = ref.read(onboardingControllerProvider.notifier);
    controller
      ..updateName(_name.text.trim())
      ..updatePhone(_phone.text.trim())
      ..updateCountry(_country);

    if (!mounted) return;
    AppSnackbar.success(context, 'Profile updated');
    leaveSettings(context);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final profile = ref.watch(onboardingControllerProvider).draft;

    final nameError = _showErrors ? ProfileValidator.name(_name.text) : null;
    final phoneError = _showErrors ? ProfileValidator.phone(_phone.text) : null;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Your profile',
        showBack: true,
        onBack: () => leaveSettings(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                children: [
                  Center(
                    child: Column(
                      children: [
                        AppAvatar(
                          label: _name.text.trim().isEmpty
                              ? (profile?.name ?? '?')
                              : _name.text,
                          size: 88,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Your initials, for now',
                          style: AppTypography.caption.copyWith(
                            color: finance.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const PlaceholderNote(
                    message:
                        'Uploading a photo arrives with the account service. '
                        'Until then everyone gets their initials, which need '
                        'no upload, no storage and no moderation.',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Name',
                    controller: _name,
                    hint: 'Amina Hassan',
                    error: nameError,
                    isRequired: true,
                    helper: 'How the app greets you.',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Phone',
                    controller: _phone,
                    hint: '${_country.dialCode} 712 345 678',
                    error: phoneError,
                    keyboardType: TextInputType.phone,
                    helper: 'Optional. Nothing is sent to it in this phase.',
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppDropdown<Country>(
                    label: 'Country',
                    items: Country.supported,
                    value: _country,
                    itemLabel: (country) => country.name,
                    onChanged: (country) {
                      if (country == null) return;
                      setState(() => _country = country);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sets the dialling code and suggests a currency. Change '
                    'the currency itself under Preferences.',
                    style: AppTypography.caption.copyWith(
                      color: finance.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppCard(
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.profile,
                          size: AppIconSize.md,
                          color: finance.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: AppTypography.caption.copyWith(
                                  color: finance.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                profile?.email ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: finance.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppBadge(label: 'From Google', tone: BadgeTone.neutral),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      label: 'Cancel',
                      onPressed: () => leaveSettings(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Save',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _save,
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
}
