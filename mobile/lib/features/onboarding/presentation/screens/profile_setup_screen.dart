import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../domain/profile_validator.dart';
import '../providers/auth_providers.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step 1 — who the user is.
///
/// Three fields, one of them optional and one of them not editable. That is
/// the whole point of signing in with a provider: the name and email arrive
/// already correct, so this screen is a confirmation rather than a form.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  /// Errors stay hidden until the user has tried to continue.
  ///
  /// Showing "Enter your name" under a field someone has not reached yet
  /// tells them they have done something wrong before they have done
  /// anything at all. After the first attempt the errors become live, so
  /// corrections are confirmed as they type.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingControllerProvider).draft;
    _nameController = TextEditingController(text: draft?.name ?? '');
    _phoneController = TextEditingController(text: draft?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final canContinue = ProfileValidator.canSubmitProfile(
      name: _nameController.text,
      phone: _phoneController.text,
    );

    if (!canContinue) {
      setState(() => _showErrors = true);
      return;
    }

    context.go(Routes.onboardingPreferences);
  }

  /// Going back from the first step means abandoning the session, because
  /// there is nowhere behind it but the welcome screen the user has already
  /// signed in from. Confirming first keeps a stray back-tap from throwing
  /// away a sign-in.
  Future<void> _onBack() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Leave setup?',
      message:
          'You will be signed out and returned to the welcome screen. '
          'Nothing you have entered is saved yet.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep setting up',
      icon: AppIcons.back,
    );

    if (confirmed != true) return;

    ref.read(onboardingControllerProvider.notifier).reset();
    await ref.read(authControllerProvider.notifier).signOut();
    // The router's guard sends an unauthenticated user to welcome, so there
    // is no navigation call here.
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider).draft;

    // The guard should make this unreachable; rendering nothing for the one
    // frame between sign-out and redirect is cheaper than an assertion.
    if (draft == null) return const SizedBox.shrink();

    final controller = ref.read(onboardingControllerProvider.notifier);
    final nameError = _showErrors
        ? ProfileValidator.name(_nameController.text)
        : null;
    final phoneError = _showErrors
        ? ProfileValidator.phone(_phoneController.text)
        : null;

    return OnboardingScaffold(
      step: 1,
      totalSteps: 3,
      title: 'About you',
      subtitle: 'We have filled in what Google told us. Change anything that '
          'is not right.',
      onBack: _onBack,
      backTooltip: 'Leave setup',
      footer: AppButton.primary(
        label: 'Continue',
        onPressed: _onContinue,
      ),
      children: [
        AppTextField(
          label: 'Your name',
          controller: _nameController,
          hint: 'How should we greet you?',
          prefixIcon: AppIcons.profile,
          isRequired: true,
          error: nameError,
          textInputAction: TextInputAction.next,
          onChanged: (value) {
            controller.updateName(value);
            if (_showErrors) setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        _ReadOnlyEmail(email: draft.email),
        const SizedBox(height: AppSpacing.xl),

        AppTextField(
          label: 'Phone number',
          controller: _phoneController,
          hint: '${draft.country.dialCode} 712 345 678',
          // Kept short: the field's helper renders on a single line and
          // ellipsises, so a longer sentence loses its own ending.
          helper: 'Optional. For mobile money later.',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          error: phoneError,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            controller.updatePhone(value);
            if (_showErrors) setState(() {});
          },
        ),
      ],
    );
  }
}

/// The provider's email, shown but not editable.
///
/// Rendered as a labelled surface rather than a disabled [AppTextField]: a
/// greyed-out input invites people to tap it and wonder why nothing happens,
/// whereas this reads as a fact about the account. The lock icon says why in
/// less space than a sentence would.
class _ReadOnlyEmail extends StatelessWidget {
  const _ReadOnlyEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: AppTypography.label.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          readOnly: true,
          label: 'Email, $email, from your Google account and not editable',
          excludeSemantics: true,
          child: Container(
            width: double.infinity,
            height: AppSpacing.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: finance.surfaceMuted,
              borderRadius: AppRadius.inputAll,
              border: Border.all(color: finance.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: AppIconSize.md,
                  color: finance.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.lock_outline_rounded,
                  size: AppIconSize.sm,
                  color: finance.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'From your Google account',
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
      ],
    );
  }
}
