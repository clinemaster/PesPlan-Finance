/// The languages the interface offers.
///
/// Phase 03 presents the choice and records it. Nothing is translated yet —
/// the strings are English throughout — so this is a stored preference, not a
/// live locale switch. Wiring it to real localisation is a later phase, and
/// the preferences screen says as much rather than implying the app will
/// change language on selection.
enum AppLanguage {
  english(code: 'en', label: 'English'),
  swahili(code: 'sw', label: 'Kiswahili');

  const AppLanguage({required this.code, required this.label});

  /// ISO 639-1, ready to become a [Locale] when localisation lands.
  final String code;

  /// Written in the language itself, which is how a speaker finds their own
  /// language in a list they cannot otherwise read.
  final String label;

  /// Kiswahili is the national language of the launch market, but the
  /// interface only exists in English today, so English is the honest
  /// default.
  static const AppLanguage initial = AppLanguage.english;
}
