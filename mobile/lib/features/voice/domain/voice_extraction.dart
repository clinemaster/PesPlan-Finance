import '../../transactions/domain/transaction_draft.dart';
import 'voice_language.dart';

/// What the speech service heard.
class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    required this.language,
    this.isEdited = false,
  });

  final String text;

  /// The language the service believes it heard, which with
  /// [VoiceLanguage.automatic] is the part it had to work out.
  final VoiceLanguage language;

  /// True once the user has corrected it by hand. Carried so the screen
  /// can stop calling it "what we heard" after the user has rewritten it.
  final bool isEdited;

  bool get isEmpty => text.trim().isEmpty;

  VoiceTranscript copyWith({String? text, bool? isEdited}) => VoiceTranscript(
    text: text ?? this.text,
    language: language,
    isEdited: isEdited ?? this.isEdited,
  );
}

/// A field the extraction could not fill confidently.
enum VoiceField {
  type,
  amount,
  category,
  date,
  description;

  String get label => switch (this) {
    VoiceField.type => 'Money in or out',
    VoiceField.amount => 'Amount',
    VoiceField.category => 'Category',
    VoiceField.date => 'Date',
    VoiceField.description => 'Description',
  };

  /// What the user is asked, in their terms.
  ///
  /// Never "low confidence" or "parse failure": the user did nothing
  /// wrong, and the app is the one that did not understand.
  String get question => switch (this) {
    VoiceField.type =>
      "We couldn't tell whether that was money in or money out. Please "
          'choose.',
    VoiceField.amount =>
      "We couldn't confidently identify the amount. Please enter it.",
    VoiceField.category =>
      "We couldn't work out a category for this. Please choose one.",
    VoiceField.date =>
      "We couldn't tell which day you meant. Please check the date.",
    VoiceField.description => 'Add a note if this needs one.',
  };
}

/// What was understood from a transcript, and what was not.
///
/// ## Nothing here is saved on its own
///
/// Every field is a suggestion. The screen presents it as one, the user
/// confirms it, and only then does a transaction exist — a voice feature
/// that files money on its own is one people stop trusting the first time
/// it mishears.
class VoiceExtraction {
  const VoiceExtraction({
    required this.transcript,
    required this.draft,
    this.uncertain = const {},
  });

  final VoiceTranscript transcript;

  /// What was understood, as far as it went.
  final TransactionDraft draft;

  /// The fields the service is not sure about. The screen marks these and
  /// refuses to treat the draft as ready while any of them matter.
  final Set<VoiceField> uncertain;

  bool isUncertainAbout(VoiceField field) => uncertain.contains(field);

  /// Whether this could go straight to saving.
  ///
  /// A note is never required and a date always has a default, so only
  /// the three fields that decide what the record actually says can block
  /// it.
  bool get isReadyToSave =>
      draft.isComplete &&
      !uncertain.contains(VoiceField.amount) &&
      !uncertain.contains(VoiceField.category) &&
      !uncertain.contains(VoiceField.type);

  /// The fields worth putting in front of the user, in reading order.
  List<VoiceField> get needsReview => [
    for (final field in VoiceField.values)
      if (uncertain.contains(field)) field,
  ];

  VoiceExtraction copyWith({
    VoiceTranscript? transcript,
    TransactionDraft? draft,
    Set<VoiceField>? uncertain,
  }) => VoiceExtraction(
    transcript: transcript ?? this.transcript,
    draft: draft ?? this.draft,
    uncertain: uncertain ?? this.uncertain,
  );
}
