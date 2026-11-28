import 'voice_extraction.dart';
import 'voice_language.dart';

/// Turning speech into a transaction, in two steps.
///
/// ## Two calls, not one
///
/// Transcription and extraction are separate because the user sits
/// between them: they see what was heard, correct it if it is wrong, and
/// only then is anything worked out from it. A single
/// `speechToTransaction` call would make that correction impossible, and
/// correcting a misheard word is far easier than correcting four fields
/// derived from it.
///
/// Phase 17 replaces the mock with a real speech service and extractor.
/// Nothing above this interface knows which is in use — the UI drives
/// stages and shows results, and it does not care whether the text came
/// from a model or from a list.
abstract interface class VoiceRepository {
  /// What the user said, as text.
  ///
  /// [spoken] is how long the microphone was open; a real service uses
  /// the audio, and the mock uses the duration to decide whether anything
  /// was said at all.
  Future<VoiceTranscript> transcribe({
    required VoiceLanguage language,
    required Duration spoken,
  });

  /// What that text appears to describe, with the parts it is unsure of
  /// marked rather than guessed.
  Future<VoiceExtraction> extract(VoiceTranscript transcript);
}

/// Thrown when speech could not be turned into text at all.
///
/// Carries a sentence meant for the user, not a code: the screen shows
/// [message] as written.
class VoiceFailure implements Exception {
  const VoiceFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
