import '../../../core/money/money.dart';
import 'app_language.dart';
import 'auth_user.dart';
import 'country.dart';

/// Everything onboarding collects, in one immutable value.
///
/// The flow builds this up across two screens, so it exists in a partly
/// filled state for most of its life. That is why [phone] is nullable and
/// [name] may be empty: the draft is allowed to be incomplete, and
/// [isComplete] is the single place that decides when it is not.
///
/// Keeping it immutable with [copyWith] means a back navigation cannot
/// half-mutate it, and the controller's state transitions stay inspectable in
/// tests.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.country,
    required this.currency,
    required this.language,
    this.phone,
  });

  /// The draft a user starts with immediately after signing in.
  ///
  /// Seeding the name and email from the provider is the reason this flow can
  /// be two short screens instead of a registration form: the first field is
  /// already filled in correctly for most people, and they only have to
  /// confirm it.
  factory UserProfile.fromAuthUser(AuthUser user) => UserProfile(
    name: user.displayName,
    email: user.email,
    country: Country.initial,
    currency: Country.initial.currency,
    language: AppLanguage.initial,
  );

  final String name;

  /// From the identity provider. Never edited in this flow.
  final String email;

  /// Optional, and genuinely optional: nothing in the flow blocks on it.
  /// `null` and empty both mean "not given".
  final String? phone;

  final Country country;
  final Currency currency;
  final AppLanguage language;

  /// True when the required answers are present.
  ///
  /// Only the name can actually be missing — country, currency and language
  /// always hold a default — but stating the rule here rather than in a
  /// screen keeps "what counts as finished" in one place.
  bool get isComplete => name.trim().isNotEmpty;

  /// True when the user chose to skip the optional phone number.
  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    bool clearPhone = false,
    Country? country,
    Currency? currency,
    AppLanguage? language,
  }) => UserProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    // A nullable field cannot be cleared by passing null — that is
    // indistinguishable from "leave it alone" — so clearing is explicit.
    phone: clearPhone ? null : (phone ?? this.phone),
    country: country ?? this.country,
    currency: currency ?? this.currency,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.country == country &&
      other.currency == currency &&
      other.language == language;

  @override
  int get hashCode =>
      Object.hash(name, email, phone, country, currency, language);

  @override
  String toString() =>
      'UserProfile($name, $email, phone: $phone, ${country.code}, '
      '${currency.code}, ${language.code})';
}
