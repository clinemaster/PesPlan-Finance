import '../domain/voice_extraction.dart';
import '../domain/voice_language.dart';
import '../domain/voice_repository.dart';
import 'transcript_reader.dart';

/// What the next attempt will hear.
///
/// The mock cycles through these so every state in the flow is reachable
/// from the screen itself — press the microphone four times and you have
/// seen a clean expense, a clean income, an extraction that needs review
/// and a failure. A build where only the happy path can be reached is a
/// build whose error state nobody has looked at.
enum VoiceScenario {
  /// A sentence with everything in it.
  clearExpense,

  /// The other side of the ledger.
  clearIncome,

  /// A sentence with no amount in it — the case that must never be
  /// guessed at.
  missingAmount,

  /// Nothing usable came back.
  failure,
}

/// Speech, while there is no speech service.
///
/// ## No microphone is opened, and nothing is sent anywhere
///
/// There is no recording, no audio, no permission request and no network
/// call. The screen runs a timer, and this class answers with a sentence
/// from a list as though something had listened. That is the whole
/// pretence, and it is kept in one file so Phase 17 can delete it.
///
/// What is *not* pretend is [TranscriptReader]: the transcript the user
/// edits is really read, so correcting "elfu kumi" to "elfu ishirini"
/// really does change the amount. Without that, the correction step would
/// be theatre.
class MockVoiceRepository implements VoiceRepository {
  MockVoiceRepository({
    required this.now,
    this.delay = const Duration(milliseconds: 900),
    VoiceScenario? scenario,
  }) : _fixed = scenario;

  final DateTime Function() now;

  /// Long enough that "Understanding your transaction…" is a state the
  /// user actually sees. Tests pass zero.
  final Duration delay;

  /// Pinned by tests; null means cycle.
  final VoiceScenario? _fixed;

  int _attempt = 0;

  /// What the next [transcribe] will produce. Exposed for tests and for
  /// the review build's own sanity.
  VoiceScenario get nextScenario =>
      _fixed ?? VoiceScenario.values[_attempt % VoiceScenario.values.length];

  @override
  Future<VoiceTranscript> transcribe({
    required VoiceLanguage language,
    required Duration spoken,
  }) async {
    await Future<void>.delayed(delay);

    // A tap that opens and closes the microphone has heard nothing, and
    // saying so is more honest than inventing a sentence.
    if (spoken < const Duration(seconds: 1)) {
      throw const VoiceFailure(
        "That was too short for us to hear anything. Hold the button while "
        'you speak.',
      );
    }

    final attempt = _attempt;
    final scenario = nextScenario;
    _attempt++;

    if (scenario == VoiceScenario.failure) {
      throw const VoiceFailure(
        "We couldn't make out what was said. Try again somewhere quieter, "
        'or enter it yourself.',
      );
    }

    return VoiceTranscript(
      text: _sentenceFor(scenario, language, attempt),
      // With automatic, the language is the part the service worked out,
      // so it reports what it decided rather than echoing the setting.
      language: language == VoiceLanguage.automatic
          ? _languageOf(attempt)
          : language,
    );
  }

  @override
  Future<VoiceExtraction> extract(VoiceTranscript transcript) async {
    await Future<void>.delayed(delay);
    return TranscriptReader.read(transcript, now());
  }

  /// The sentences the mock "hears".
  ///
  /// Written the way people actually speak in the launch market, mixing
  /// English nouns into Kiswahili where that is what happens, so the
  /// reader is exercised on realistic input rather than on textbook
  /// sentences.
  String _sentenceFor(
    VoiceScenario scenario,
    VoiceLanguage language,
    int attempt,
  ) {
    final swahili = switch (language) {
      VoiceLanguage.swahili => true,
      VoiceLanguage.english => false,
      // Alternating, so a user on Automatic sees both get handled.
      VoiceLanguage.automatic => attempt.isEven,
    };

    return switch ((scenario, swahili)) {
      (VoiceScenario.clearExpense, true) =>
        'Nimetumia shilingi elfu kumi kwa chakula',
      (VoiceScenario.clearExpense, false) =>
        'I spent ten thousand shillings on food',
      (VoiceScenario.clearIncome, true) => 'Nimepokea mshahara wa milioni moja',
      (VoiceScenario.clearIncome, false) =>
        'I received one million shillings as salary',
      (VoiceScenario.missingAmount, true) => 'Nimelipia umeme leo',
      (VoiceScenario.missingAmount, false) => 'I paid for electricity today',
      (VoiceScenario.failure, _) => '',
    };
  }

  VoiceLanguage _languageOf(int attempt) =>
      attempt.isEven ? VoiceLanguage.swahili : VoiceLanguage.english;
}
