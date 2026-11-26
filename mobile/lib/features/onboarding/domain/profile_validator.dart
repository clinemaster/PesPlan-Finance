/// Frontend validation for the onboarding form.
///
/// Pure functions returning a user-facing message, or `null` when the value
/// is acceptable — the same shape as the `error` parameter on the design
/// system's fields, so a screen can pass the result straight through without
/// translating it.
///
/// This is presentation-level validation only: it catches typos before a user
/// moves on. It is not a security boundary, and the server will validate
/// again when Phase 12 connects one. Keeping it pure (no widgets, no
/// providers) is what lets the rules be tested directly.
abstract final class ProfileValidator {
  static const int nameMinLength = 2;
  static const int nameMaxLength = 60;

  /// E.164 allows at most 15 digits; 7 is about the shortest real national
  /// number. Anything outside that is a typo rather than a number we should
  /// try to accept.
  static const int phoneMinDigits = 7;
  static const int phoneMaxDigits = 15;

  static final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _phoneShape = RegExp(r'^\+?[0-9]+$');

  /// Characters people habitually type into a phone field that carry no
  /// meaning: spaces, dashes, dots and bracketed area codes.
  static final RegExp _phoneNoise = RegExp(r'[\s\-().]');

  /// The display name. Required.
  ///
  /// The letter check exists because the field is pre-filled from the
  /// identity provider and then edited; "123" or "..." passes a pure length
  /// check but is not a name anyone meant to enter.
  static String? name(String? value) {
    final trimmed = (value ?? '').trim();

    if (trimmed.isEmpty) {
      return 'Enter your name so we know what to call you';
    }
    if (trimmed.length < nameMinLength) {
      return 'That looks too short — use at least $nameMinLength characters';
    }
    if (trimmed.length > nameMaxLength) {
      return 'Keep your name under $nameMaxLength characters';
    }
    if (!_hasLetter.hasMatch(trimmed)) {
      return 'A name needs at least one letter';
    }
    return null;
  }

  /// The phone number. Optional.
  ///
  /// Empty is valid and must stay valid: the flow promises the field can be
  /// skipped, and a validator that quietly disagrees would strand the user on
  /// a screen whose Continue button never enables.
  ///
  /// Only the shape is checked. Whether a number is reachable is not
  /// knowable here, and guessing per-country rules would reject valid numbers
  /// from markets this app has not launched in yet.
  static String? phone(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;

    final compact = trimmed.replaceAll(_phoneNoise, '');

    if (!_phoneShape.hasMatch(compact)) {
      return 'Use digits only, optionally starting with +';
    }

    final digits = compact.startsWith('+') ? compact.substring(1) : compact;

    if (digits.length < phoneMinDigits) {
      return 'That number looks too short';
    }
    if (digits.length > phoneMaxDigits) {
      return 'That number looks too long';
    }
    return null;
  }

  /// Whether the form as a whole may advance.
  ///
  /// Expressed in terms of the field validators rather than repeating their
  /// rules, so a change to [name] or [phone] cannot leave the Continue button
  /// out of step with the errors shown under the fields.
  static bool canSubmitProfile({required String? name, required String? phone}) =>
      ProfileValidator.name(name) == null && ProfileValidator.phone(phone) == null;
}
