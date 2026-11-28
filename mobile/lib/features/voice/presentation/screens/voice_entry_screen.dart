import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/voice_extraction.dart';
import '../../domain/voice_session.dart';
import '../providers/voice_providers.dart';
import '../widgets/voice_widgets.dart';

/// Leaves the voice screen.
///
/// Normally a pop, because the screen is pushed over whatever the user
/// was doing. A deep link straight to it has nothing underneath, so it
/// falls back to the dashboard rather than throwing — the user did not
/// ask to be stranded on a screen with no way back.
void _leaveVoice(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
  }
}

/// Saying a transaction instead of typing it.
///
/// ## One screen, six states
///
/// Ready, listening, understanding, what-we-heard, what-we-understood,
/// and something-went-wrong. They are stages of one attempt rather than
/// separate screens: the user's place in the flow never moves, only what
/// the screen is showing them, and Cancel always means the same thing.
///
/// ## Nothing is saved until the user says so
///
/// The extraction is a suggestion, shown as one. A voice feature that
/// files money on its own is one people stop trusting the first time it
/// mishears — so the primary button is a confirmation, and every field it
/// is confirming can be changed first.
class VoiceEntryScreen extends ConsumerWidget {
  const VoiceEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);

    return PopScope(
      // Leaving mid-attempt throws the attempt away rather than leaving a
      // timer running behind a screen nobody is looking at.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.reset();
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Say it',
          showBack: true,
          onBack: () {
            controller.reset();
            _leaveVoice(context);
          },
        ),
        body: SafeArea(
          child: switch (session.stage) {
            VoiceStage.idle => _Idle(session: session),
            VoiceStage.recording => _Recording(session: session),
            VoiceStage.processing => const _Processing(),
            VoiceStage.transcribed => _Transcribed(session: session),
            VoiceStage.review || VoiceStage.saving => _Review(session: session),
            VoiceStage.error => _Error(session: session),
          },
        ),
      ),
    );
  }
}

/// Ready, and explaining itself.
class _Idle extends ConsumerWidget {
  const _Idle({required this.session});

  final VoiceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final controller = ref.read(voiceControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          'What did you spend or earn?',
          textAlign: TextAlign.center,
          style: AppTypography.titleScreen.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Just say it naturally. We'll help organise it.",
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: finance.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Center(
          child: MicButton(
            isRecording: false,
            onPressed: controller.startRecording,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tap to start',
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(color: finance.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        LanguagePicker(
          value: session.language,
          onChanged: controller.setLanguage,
        ),
        const SizedBox(height: AppSpacing.xl),

        VoiceExamples(language: session.language),
        const SizedBox(height: AppSpacing.lg),

        // The way out, kept quiet but kept present: a voice feature that
        // corners someone into using it is worse than no voice feature.
        AppButton.text(
          label: 'Enter transaction manually',
          icon: AppIcons.edit,
          isFullWidth: true,
          onPressed: () => context.pushReplacement(Routes.transactionNew),
        ),
      ],
    );
  }
}

/// Listening, and saying so.
class _Recording extends ConsumerWidget {
  const _Recording({required this.session});

  final VoiceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final controller = ref.read(voiceControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        children: [
          const Spacer(),
          Semantics(
            liveRegion: true,
            label: 'Recording, ${session.elapsedLabel}',
            excludeSemantics: true,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: AppSpacing.sm,
                      height: AppSpacing.sm,
                      decoration: BoxDecoration(
                        color: finance.expense,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      session.language.listening,
                      style: AppTypography.label.copyWith(
                        color: finance.expenseText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  session.elapsedLabel,
                  style: AppTypography.amountLarge.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          MicButton(isRecording: true, onPressed: controller.stopRecording),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tap to stop when you are done',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),

          const Spacer(),
          AppButton.primary(
            label: 'Stop and continue',
            onPressed: controller.stopRecording,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.text(
            label: 'Cancel',
            isFullWidth: true,
            onPressed: controller.cancel,
          ),
        ],
      ),
    );
  }
}

/// Working it out.
class _Processing extends StatelessWidget {
  const _Processing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: LoadingState(message: 'Understanding your transaction…'),
    );
  }
}

/// What we heard, before anything is derived from it.
class _Transcribed extends ConsumerStatefulWidget {
  const _Transcribed({required this.session});

  final VoiceSession session;

  @override
  ConsumerState<_Transcribed> createState() => _TranscribedState();
}

class _TranscribedState extends ConsumerState<_Transcribed> {
  late final TextEditingController _text = TextEditingController(
    text: widget.session.transcript?.text ?? '',
  );
  bool _isEditing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final controller = ref.read(voiceControllerProvider.notifier);
    final transcript = widget.session.transcript;
    if (transcript == null) return const SizedBox.shrink();

    return Column(
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
              if (_isEditing)
                AppTextField(
                  label: 'What you said',
                  controller: _text,
                  maxLines: 3,
                  autofocus: true,
                  helper: 'Fix a word we got wrong and we will read it again.',
                )
              else
                TranscriptCard(transcript: transcript),
              const SizedBox(height: AppSpacing.lg),

              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Discard',
                        onPressed: () => setState(() {
                          _text.text = transcript.text;
                          _isEditing = false;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton.primary(
                        label: 'Use this',
                        onPressed: () async {
                          setState(() => _isEditing = false);
                          await controller.applyTranscript(_text.text);
                        },
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Edit text',
                        icon: AppIcons.edit,
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Try again',
                        icon: AppIcons.refresh,
                        onPressed: controller.reset,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'Nothing is saved yet. The next screen shows what we '
                'understood, for you to check.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: finance.textTertiary,
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
          child: AppButton.primary(
            label: 'Continue',
            onPressed: _isEditing ? null : controller.review,
          ),
        ),
      ],
    );
  }
}

/// What we understood, for the user to confirm or correct.
class _Review extends ConsumerWidget {
  const _Review({required this.session});

  final VoiceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final controller = ref.read(voiceControllerProvider.notifier);
    final extraction = session.extraction;
    if (extraction == null) return const SizedBox.shrink();

    final draft = extraction.draft;
    final isSaving = session.stage == VoiceStage.saving;

    return Column(
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: finance.infoSurface,
                  borderRadius: AppRadius.cardAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info,
                      size: AppIconSize.sm,
                      color: finance.infoText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Please review your transaction before saving. These '
                        'are suggestions from what you said.',
                        style: AppTypography.caption.copyWith(
                          color: finance.infoText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              TranscriptCard(transcript: extraction.transcript),
              const SizedBox(height: AppSpacing.lg),

              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    ExtractedRow(
                      label: 'Money',
                      value: switch (draft.type) {
                        TransactionType.expense => 'Out',
                        TransactionType.income => 'In',
                        null => null,
                      },
                      isUncertain: extraction.isUncertainAbout(VoiceField.type),
                      question: VoiceField.type.question,
                      onEdit: () => _openForm(context, ref),
                    ),
                    const AppDivider(),
                    ExtractedRow(
                      label: 'Amount',
                      value: draft.magnitudeMinorUnits == null
                          ? null
                          : Money(draft.magnitudeMinorUnits!).format(),
                      isUncertain: extraction.isUncertainAbout(
                        VoiceField.amount,
                      ),
                      question: VoiceField.amount.question,
                      onEdit: () => _openForm(context, ref),
                    ),
                    const AppDivider(),
                    ExtractedRow(
                      label: 'Category',
                      value: draft.categoryLabel,
                      isUncertain: extraction.isUncertainAbout(
                        VoiceField.category,
                      ),
                      question: VoiceField.category.question,
                      onEdit: () => _openForm(context, ref),
                    ),
                    const AppDivider(),
                    ExtractedRow(
                      label: 'Date',
                      value: draft.date == null
                          ? null
                          : DateLabels.full(draft.date!),
                      isUncertain: extraction.isUncertainAbout(VoiceField.date),
                      question: VoiceField.date.question,
                      onEdit: () => _openForm(context, ref),
                    ),
                    const AppDivider(),
                    ExtractedRow(
                      label: 'Description',
                      value: draft.description.isEmpty
                          ? null
                          : draft.description,
                      emptyLabel: 'None',
                      onEdit: () => _openForm(context, ref),
                    ),
                    const AppDivider(),
                    ExtractedRow(
                      label: 'Currency',
                      value: Currency.tzs.code,
                      onEdit: () => _openForm(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              AppButton.text(
                label: 'Back to what you said',
                icon: AppIcons.back,
                isFullWidth: true,
                onPressed: controller.backToTranscript,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (extraction.isReadyToSave)
                AppButton.primary(
                  label: 'Confirm & save',
                  icon: AppIcons.check,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : () => _save(context, ref),
                )
              else
                // Nothing to confirm yet: the missing field has to be
                // filled before there is a transaction to agree to, so
                // the primary action takes the user there rather than
                // offering a save that would be refused.
                AppButton.primary(
                  label: 'Add the missing details',
                  icon: AppIcons.edit,
                  onPressed: () => _openForm(context, ref),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  // Only alongside a confirmation. When the primary
                  // button already says "Add the missing details", a
                  // second one going to the same form is just a second
                  // way to say the same thing.
                  if (extraction.isReadyToSave)
                    Expanded(
                      child: AppButton.text(
                        label: 'Edit details',
                        onPressed: () => _openForm(context, ref),
                      ),
                    ),
                  Expanded(
                    child: AppButton.text(
                      label: 'Cancel',
                      onPressed: () {
                        controller.cancel();
                        _leaveVoice(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Hands the draft to the form from Phase 05.
  ///
  /// `pushReplacement`, not `push`: the voice screen has done its job
  /// once the fields are on a form, and leaving it underneath would let
  /// the user save the same thing twice — once on the form and again on
  /// the review it came back to.
  void _openForm(BuildContext context, WidgetRef ref) {
    final draft = ref.read(voiceControllerProvider).extraction?.draft;
    ref.read(voiceControllerProvider.notifier).reset();
    context.pushReplacement(Routes.transactionNew, extra: draft);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final draft = session.extraction!.draft;
    final actions = ref.read(transactionActionsProvider);
    final today = ref.read(clockProvider)();

    controller.saving();

    try {
      await actions.add(
        Transaction.create(
          id: actions.newId(),
          type: draft.type!,
          magnitudeMinorUnits: draft.magnitudeMinorUnits!,
          categoryId: draft.categoryId!,
          categoryLabel: draft.categoryLabel!,
          description: draft.description.trim(),
          date: draft.date ?? today,
          createdAt: today,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      controller.saveFailed('$error');
      AppSnackbar.error(context, 'Could not save that. $error');
      return;
    }

    controller.reset();
    if (!context.mounted) return;
    AppSnackbar.success(context, 'Transaction saved');
    _leaveVoice(context);
  }
}

/// Something went wrong, said in a way that does not blame the user.
class _Error extends ConsumerWidget {
  const _Error({required this.session});

  final VoiceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: AppIcons.voice,
              title: 'We did not catch that',
              message:
                  session.errorMessage ??
                  'Please try again, or enter the transaction yourself.',
              actionLabel: 'Try again',
              actionIcon: AppIcons.refresh,
              onAction: controller.reset,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.text(
              label: 'Enter transaction manually',
              icon: AppIcons.edit,
              isFullWidth: true,
              onPressed: () {
                controller.reset();
                context.pushReplacement(Routes.transactionNew);
              },
            ),
          ],
        ),
      ),
    );
  }
}
