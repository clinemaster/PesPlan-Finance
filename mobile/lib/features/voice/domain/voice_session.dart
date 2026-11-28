import 'voice_extraction.dart';
import 'voice_language.dart';

/// Where the user is in one attempt at speaking a transaction.
enum VoiceStage {
  /// Nothing has happened yet. The microphone is offered, not open.
  idle,

  /// The microphone is open — or would be, in a build that had one.
  recording,

  /// Working out what was said.
  processing,

  /// There is a transcript, and the user can correct it before going on.
  transcribed,

  /// There is an extraction to review.
  review,

  /// Saving the confirmed transaction.
  saving,

  /// Something went wrong, said plainly.
  error;

  bool get isRecording => this == VoiceStage.recording;

  bool get isBusy => this == VoiceStage.processing || this == VoiceStage.saving;
}

/// One attempt at speaking a transaction, start to finish.
///
/// Held as a single immutable value rather than a handful of booleans, so
/// the screen renders one state and cannot show a spinner over a
/// transcript or a stop button when nothing is recording.
class VoiceSession {
  const VoiceSession({
    this.stage = VoiceStage.idle,
    this.language = VoiceLanguage.automatic,
    this.elapsed = Duration.zero,
    this.extraction,
    this.errorMessage,
  });

  final VoiceStage stage;
  final VoiceLanguage language;

  /// How long the microphone has been open. Shown so the user can see
  /// that something is happening even in silence.
  final Duration elapsed;

  /// Present from [VoiceStage.transcribed] onward.
  final VoiceExtraction? extraction;

  final String? errorMessage;

  VoiceTranscript? get transcript => extraction?.transcript;

  /// mm:ss, which is all a recording this short ever needs.
  String get elapsedLabel {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  VoiceSession copyWith({
    VoiceStage? stage,
    VoiceLanguage? language,
    Duration? elapsed,
    VoiceExtraction? extraction,
    bool clearExtraction = false,
    String? errorMessage,
    bool clearError = false,
  }) => VoiceSession(
    stage: stage ?? this.stage,
    language: language ?? this.language,
    elapsed: elapsed ?? this.elapsed,
    extraction: clearExtraction ? null : (extraction ?? this.extraction),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
