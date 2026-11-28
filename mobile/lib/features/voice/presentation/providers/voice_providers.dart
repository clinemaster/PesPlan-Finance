import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../transactions/domain/transaction_draft.dart';
import '../../data/mock_voice_repository.dart';
import '../../domain/voice_extraction.dart';
import '../../domain/voice_language.dart';
import '../../domain/voice_repository.dart';
import '../../domain/voice_session.dart';

/// Where speech comes from.
///
/// Phase 17 overrides this with a real speech service; nothing above it
/// changes, because the stages and the two calls stay the same.
final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => MockVoiceRepository(now: ref.watch(clockProvider)),
);

/// One attempt at speaking a transaction.
///
/// ## Why the whole flow is one controller
///
/// Recording, transcribing, correcting and reviewing are four screens'
/// worth of UI and one piece of state. Splitting them would mean handing
/// a half-finished extraction between routes and keeping a timer alive
/// across them; keeping them together means the back button and Cancel
/// have exactly one thing to undo.
class VoiceController extends Notifier<VoiceSession> {
  Timer? _ticker;

  @override
  VoiceSession build() {
    ref.onDispose(_stopTicker);
    return const VoiceSession();
  }

  VoiceRepository get _repository => ref.read(voiceRepositoryProvider);

  void setLanguage(VoiceLanguage language) {
    state = state.copyWith(language: language);
  }

  /// Opens the "microphone" and starts counting.
  ///
  /// Nothing is recorded: there is no audio in this phase. The timer
  /// exists because a user staring at a still screen cannot tell whether
  /// the app is listening, and the elapsed seconds are the cheapest
  /// honest signal that it is.
  void startRecording() {
    _stopTicker();
    state = state.copyWith(
      stage: VoiceStage.recording,
      elapsed: Duration.zero,
      clearExtraction: true,
      clearError: true,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.stage.isRecording) return;
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });
  }

  /// Stops listening and works out what was said.
  Future<void> stopRecording() async {
    if (!state.stage.isRecording) return;

    _stopTicker();
    final spoken = state.elapsed;
    state = state.copyWith(stage: VoiceStage.processing);

    try {
      final transcript = await _repository.transcribe(
        language: state.language,
        spoken: spoken,
      );
      final extraction = await _repository.extract(transcript);

      // Cancelled while we were working: the user has moved on, and
      // dropping a result on them now would be a screen changing under
      // their hands.
      if (state.stage != VoiceStage.processing) return;

      state = state.copyWith(
        stage: VoiceStage.transcribed,
        extraction: extraction,
      );
    } on VoiceFailure catch (failure) {
      if (state.stage != VoiceStage.processing) return;
      state = state.copyWith(
        stage: VoiceStage.error,
        errorMessage: failure.message,
      );
    } catch (error) {
      if (state.stage != VoiceStage.processing) return;
      state = state.copyWith(
        stage: VoiceStage.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Back to the start, keeping the chosen language.
  void reset() {
    _stopTicker();
    state = VoiceSession(language: state.language);
  }

  /// Abandons the attempt. Nothing is saved, because nothing has been.
  void cancel() => reset();

  /// The user has corrected what we heard.
  ///
  /// Re-reads the corrected sentence rather than keeping the old
  /// extraction: correcting "elfu kumi" to "elfu ishirini" has to change
  /// the amount, or the correction step is decoration.
  Future<void> applyTranscript(String text) async {
    final current = state.extraction;
    if (current == null) return;

    final corrected = current.transcript.copyWith(
      text: text,
      isEdited: text.trim() != current.transcript.text.trim(),
    );

    state = state.copyWith(stage: VoiceStage.processing);
    final extraction = await _repository.extract(corrected);

    if (state.stage != VoiceStage.processing) return;
    state = state.copyWith(
      stage: VoiceStage.transcribed,
      extraction: extraction,
    );
  }

  /// Moves from "this is what we heard" to "this is what we understood".
  void review() {
    if (state.extraction == null) return;
    state = state.copyWith(stage: VoiceStage.review);
  }

  /// Back from the review to the transcript, to fix a misheard word.
  void backToTranscript() {
    if (state.extraction == null) return;
    state = state.copyWith(stage: VoiceStage.transcribed);
  }

  /// A field the user corrected on the review card.
  ///
  /// Correcting a field also settles it: the service was unsure, the user
  /// has now said, and continuing to mark it for review would be arguing
  /// with them.
  void updateDraft(
    TransactionDraft draft, {
    Set<VoiceField> settled = const {},
  }) {
    final current = state.extraction;
    if (current == null) return;

    state = state.copyWith(
      extraction: current.copyWith(
        draft: draft,
        uncertain: {...current.uncertain}..removeAll(settled),
      ),
    );
  }

  /// Marks the attempt as saving, so the button cannot be pressed twice.
  void saving() => state = state.copyWith(stage: VoiceStage.saving);

  /// Puts the review back when a save failed.
  void saveFailed(String message) =>
      state = state.copyWith(stage: VoiceStage.review, errorMessage: message);

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceSession>(
  VoiceController.new,
);
