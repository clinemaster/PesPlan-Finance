/// The spacing scale.
///
/// A 4pt base grid, which matches Android's density buckets and keeps every
/// gap a multiple of the same unit. Inconsistent spacing is the most visible
/// symptom of an ad-hoc UI, so screens must compose from this scale and never
/// invent a value.
///
/// Names are sizes, not purposes, because the same gap serves many purposes.
/// The purpose-named constants at the bottom cover the handful of decisions
/// that should be made once for the whole app.
abstract final class AppSpacing {
  const AppSpacing._();

  /// 2 — hairline separation; the gap between touching chart marks.
  static const double xxs = 2;

  /// 4 — icon-to-label inside a dense chip.
  static const double xs = 4;

  /// 8 — related elements: a label above its field.
  static const double sm = 8;

  /// 12 — inside a compact card or list row.
  static const double md = 12;

  /// 16 — the default. Screen padding and standard card padding.
  static const double lg = 16;

  /// 20 — generous card padding for a hero surface.
  static const double xl = 20;

  /// 24 — between sections.
  static const double xxl = 24;

  /// 32 — between major blocks.
  static const double xxxl = 32;

  /// 48 — around an empty state or a single centred action.
  static const double huge = 48;

  // ----------------------------------------------------- settled decisions

  /// Horizontal padding at the edge of every screen. One value, everywhere.
  static const double screenH = lg;

  /// Vertical padding at the top and bottom of a scroll view.
  static const double screenV = lg;

  /// Default padding inside a card.
  static const double cardPadding = lg;

  /// Gap between stacked cards in a list.
  static const double cardGap = md;

  /// Gap between a section header and its content.
  static const double sectionGap = xxl;

  /// Minimum touch target. Material and WCAG both ask for 48; anything
  /// smaller is a bug, no matter how it looks.
  static const double minTouchTarget = 48;

  /// Height of a standard button and input.
  static const double controlHeight = 52;

  /// Height of a compact button.
  static const double controlHeightSmall = 40;
}
