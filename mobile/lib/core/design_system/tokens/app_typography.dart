import 'package:material_ui/material_ui.dart';

/// The type scale for LifePilot Finance.
///
/// ## Why these sizes
///
/// The scale is built for one-handed use on a small Android phone held at
/// arm's length, read by someone who may never have used a finance app. Body
/// text starts at **16sp**, not 14sp: 14 is comfortable for a developer
/// reviewing a dense dashboard and tiring for everyone else.
///
/// ## Financial figures are a separate class of text
///
/// An amount is the most important thing on most screens and the most costly
/// thing to misread. Amount styles therefore differ from body text in three
/// deliberate ways:
///
/// 1. **Tabular figures** (`FontFeature.tabularFigures`) so every digit has
///    the same width. Columns of amounts line up, and a changing balance does
///    not jitter as digits change.
/// 2. **Tighter letter spacing** at display sizes, which reads as composed
///    rather than loose.
/// 3. **No colour of their own.** An amount takes its colour from the theme's
///    finance semantics at the call site, never from this file.
///
/// ## Dynamic type
///
/// Nothing here hardcodes a pixel height. Sizes are in logical pixels and
/// scale with the platform text-size setting; `height` is expressed as a
/// multiple of font size so line boxes grow proportionally. Screens must not
/// cap text scaling — see `AppTypography.clampTextScale` for the one
/// sanctioned exception.
abstract final class AppTypography {
  const AppTypography._();

  /// `null` keeps the platform default (Roboto on Android, SF on iOS), which
  /// is already the most legible choice on each OS and costs no download.
  ///
  /// To adopt a brand face later, bundle the files as assets and set this to
  /// the family name — every style below inherits it, so that is a one-line
  /// change rather than a sweep.
  static const String? fontFamily = null;

  // Weights, named by role rather than number so usage reads clearly.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Digits of equal width. Essential for any column of money.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ------------------------------------------------------------- display
  // One per screen at most, for a hero figure or an onboarding headline.

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 1.15,
    fontWeight: bold,
    letterSpacing: -0.8,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.2,
    fontWeight: bold,
    letterSpacing: -0.6,
  );

  // -------------------------------------------------------------- titles

  /// Screen title, in an app bar or at the top of a scroll view.
  static const TextStyle titleScreen = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.25,
    fontWeight: semibold,
    letterSpacing: -0.3,
  );

  /// Section heading within a screen.
  static const TextStyle titleSection = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: semibold,
    letterSpacing: -0.1,
  );

  /// Card heading.
  static const TextStyle titleCard = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.35,
    fontWeight: semibold,
  );

  // ---------------------------------------------------------------- body

  /// Default body text. 16sp — the floor for comfortable reading.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: regular,
  );

  /// Supporting copy and list subtitles.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.45,
    fontWeight: regular,
  );

  /// Metadata. The smallest text in the system; never for anything essential.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: regular,
  );

  // -------------------------------------------------- labels & captions

  /// Form labels, tabs, chips.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: medium,
  );

  /// Small emphatic label: table headers, overlines, bottom-nav items.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: medium,
    letterSpacing: 0.2,
  );

  /// Caption. At 12sp this is paired only with [AppColors.textSecondary] or
  /// darker — never with the disabled tier.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: regular,
  );

  // ------------------------------------------------------------ amounts
  // Tabular, tight, and weighted. Colour is applied by the caller.

  /// The hero balance on a dashboard. One per screen.
  static const TextStyle amountHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 1.1,
    fontWeight: bold,
    letterSpacing: -0.8,
    fontFeatures: _tabular,
  );

  /// A headline figure on a summary card.
  static const TextStyle amountLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.2,
    fontWeight: semibold,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  /// The amount on a transaction row — the most frequently read style here.
  static const TextStyle amountMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.3,
    fontWeight: semibold,
    fontFeatures: _tabular,
  );

  /// A secondary or historical figure.
  static const TextStyle amountSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: medium,
    fontFeatures: _tabular,
  );

  /// Axis ticks and in-chart values. Tabular so ticks align.
  static const TextStyle amountTick = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.2,
    fontWeight: medium,
    fontFeatures: _tabular,
  );

  // ------------------------------------------------------------- button

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.2,
    fontWeight: semibold,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.2,
    fontWeight: semibold,
    letterSpacing: 0.1,
  );

  /// Upper bound on text scaling, for the rare layout that genuinely cannot
  /// reflow — a fixed-height chart axis, for example.
  ///
  /// Use sparingly and never on body copy: a user who has set large text has
  /// asked for large text. Default ceiling is generous (2x) so most users are
  /// unaffected.
  static TextScaler clampTextScale(BuildContext context, {double max = 2.0}) {
    return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: max);
  }

  /// The Material [TextTheme], so stock widgets inherit the scale too.
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primary),
      displayMedium: displayMedium.copyWith(color: primary),
      displaySmall: titleScreen.copyWith(color: primary),
      headlineLarge: titleScreen.copyWith(color: primary),
      headlineMedium: titleSection.copyWith(color: primary),
      headlineSmall: titleCard.copyWith(color: primary),
      titleLarge: titleSection.copyWith(color: primary),
      titleMedium: titleCard.copyWith(color: primary),
      titleSmall: label.copyWith(color: primary),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: bodyMedium.copyWith(color: primary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: label.copyWith(color: primary),
      labelMedium: labelSmall.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: secondary),
    );
  }
}
