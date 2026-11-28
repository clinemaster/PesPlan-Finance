/// Which language the user intends to speak.
///
/// ## Why this is a choice and not a guess
///
/// Detection will exist later; this phase has no speech service at all,
/// so offering "Automatic" alone would be a promise the app cannot keep.
/// A user in Dar es Salaam switching between Kiswahili and English
/// mid-sentence is the normal case, which is exactly why the examples
/// shown have to match what they are about to say.
enum VoiceLanguage {
  automatic,
  swahili,
  english;

  String get label => switch (this) {
    VoiceLanguage.automatic => 'Automatic',
    VoiceLanguage.swahili => 'Kiswahili',
    VoiceLanguage.english => 'English',
  };

  /// The short note under the picker.
  String get hint => switch (this) {
    VoiceLanguage.automatic =>
      'We will work out which language you used. Mixing the two is fine.',
    VoiceLanguage.swahili => 'Sema kwa Kiswahili — kama unavyozungumza.',
    VoiceLanguage.english =>
      'Say it in English, the way you would to a friend.',
  };

  /// What to say, shown before the user speaks.
  ///
  /// Real sentences rather than a grammar: people copy the example they
  /// are shown, and "Nimetumia elfu kumi kwa chakula" teaches the shape
  /// of a useful utterance better than any instruction could.
  List<String> get examples => switch (this) {
    VoiceLanguage.swahili => const [
      'Nimetumia shilingi elfu kumi kwa chakula.',
      'Nimelipa elfu tano ya nauli.',
      'Nimepokea mshahara wa milioni moja.',
    ],
    VoiceLanguage.english => const [
      'I spent ten thousand shillings on food.',
      'I paid five thousand for transport.',
      'I received one million shillings as salary.',
    ],
    // One of each, because that is what "either is fine" looks like.
    VoiceLanguage.automatic => const [
      'Nimetumia shilingi elfu kumi kwa chakula.',
      'I paid twenty thousand for electricity today.',
      'Nimenunua groceries kwa elfu arobaini na tano.',
    ],
  };

  /// What the status line says while the microphone is open.
  String get listening => switch (this) {
    VoiceLanguage.swahili => 'Ninasikiliza…',
    _ => 'Listening…',
  };
}
