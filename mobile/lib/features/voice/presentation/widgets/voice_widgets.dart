import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/voice_extraction.dart';
import '../../domain/voice_language.dart';

/// The one control this screen is about.
///
/// ## Big, round, and the only thing to press
///
/// A voice feature competing with four other buttons gets used once. The
/// microphone is the primary visual focus, everything else on the idle
/// screen is text, and the fallback to typing is a quiet link rather than
/// a second button of equal weight.
class MicButton extends StatefulWidget {
  const MicButton({
    required this.isRecording,
    required this.onPressed,
    super.key,
    this.enabled = true,
    this.size = 128,
  });

  final bool isRecording;
  final VoidCallback onPressed;
  final bool enabled;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (old.isRecording != widget.isRecording) _syncAnimation();
  }

  /// Runs only while listening, and not at all when the device asks for
  /// reduced motion.
  ///
  /// A ring that breathes forever costs battery and attention for no
  /// information; one that runs exactly while the microphone is open is
  /// the status indicator itself.
  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (widget.isRecording && !reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final colors = context.colors;

    final background = widget.isRecording ? finance.expense : colors.primary;
    final foreground = widget.isRecording ? colors.onPrimary : colors.onPrimary;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.isRecording ? 'Stop recording' : 'Start recording',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final spread = widget.isRecording ? 16 + _pulse.value * 18 : 0.0;

          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (spread > 0)
                  BoxShadow(
                    color: background.withValues(alpha: 0.18),
                    blurRadius: 0,
                    spreadRadius: spread,
                  ),
              ],
            ),
            child: child,
          );
        },
        child: Material(
          color: widget.enabled ? background : finance.surfaceMuted,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.enabled ? widget.onPressed : null,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.isRecording ? AppIcons.close : AppIcons.voice,
                size: widget.size / 2.6,
                color: widget.enabled ? foreground : finance.textDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kiswahili, English, or let us work it out.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final VoiceLanguage value;
  final ValueChanged<VoiceLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final language in VoiceLanguage.values)
              _LanguageChip(
                language: language,
                isSelected: language == value,
                onTap: () => onChanged(language),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value.hint,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: finance.textTertiary),
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final VoiceLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final foreground = isSelected
        ? context.colors.onPrimary
        : finance.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: language.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? context.colors.primary : finance.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Center with widthFactor, not alignment: a Wrap hands each
            // child unbounded width, and a Container with an alignment
            // takes all of it.
            child: Center(
              widthFactor: 1,
              child: Text(
                language.label,
                style: AppTypography.labelSmall.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What to say, in the language the user picked.
class VoiceExamples extends StatelessWidget {
  const VoiceExamples({required this.language, super.key});

  final VoiceLanguage language;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try saying',
            style: AppTypography.label.copyWith(color: finance.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final example in language.examples) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.voice,
                  size: AppIconSize.sm,
                  color: finance.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '“$example”',
                    style: AppTypography.bodySmall.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (example != language.examples.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// One line of the extraction, with its state said in words.
class ExtractedRow extends StatelessWidget {
  const ExtractedRow({
    required this.label,
    required this.value,
    required this.onEdit,
    super.key,
    this.isUncertain = false,
    this.question,
    this.emptyLabel = 'Not heard',
  });

  final String label;

  /// What was understood. Null when nothing was.
  final String? value;

  final VoidCallback onEdit;
  final bool isUncertain;
  final String? question;

  /// What an empty value reads as. "Not heard" is right for something
  /// that was meant to be picked up and was not; an optional field that
  /// nobody said anything about is not a failure, and saying so would
  /// invite the user to go and fix something that is fine.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final missing = value == null || value!.isEmpty;

    return Semantics(
      button: true,
      label: isUncertain
          ? '$label, needs review. ${question ?? ''}'
          : '$label, ${value ?? 'not set'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onEdit,
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      label,
                      style: AppTypography.bodySmall.copyWith(
                        color: finance.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      missing ? emptyLabel : value!,
                      textAlign: TextAlign.right,
                      style: AppTypography.bodyMedium.copyWith(
                        color: missing
                            ? finance.textTertiary
                            : finance.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    AppIcons.edit,
                    size: AppIconSize.sm,
                    color: finance.textTertiary,
                  ),
                ],
              ),
              if (isUncertain && question != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: finance.warningSurface,
                    borderRadius: AppRadius.inputAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.warning,
                        size: AppIconSize.sm,
                        color: finance.warningText,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          question!,
                          style: AppTypography.caption.copyWith(
                            color: finance.warningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The sentence we think we heard.
class TranscriptCard extends StatelessWidget {
  const TranscriptCard({required this.transcript, super.key});

  final VoiceTranscript transcript;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  transcript.isEdited ? 'Your correction' : 'What we heard',
                  style: AppTypography.label.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              AppBadge(
                label: transcript.language.label,
                tone: BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '“${transcript.text}”',
            style: AppTypography.titleCard.copyWith(color: finance.textPrimary),
          ),
        ],
      ),
    );
  }
}
