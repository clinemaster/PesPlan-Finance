import 'package:material_ui/material_ui.dart';

/// Corner radii.
///
/// Rounded, but not playful: 12 for cards and 12 for buttons reads as modern
/// and calm, where a pill-shaped button reads as consumer-social and a square
/// one reads as enterprise accounting. Both are the wrong register for an app
/// about someone's money.
abstract final class AppRadius {
  const AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Fully rounded — chips, avatars, progress tracks.
  static const double pill = 999;

  // Settled decisions.
  static const double card = md;
  static const double button = md;
  static const double input = md;
  static const double sheet = xxl;
  static const double dialog = lg;
  static const double badge = pill;
  static const double chartBarCap = xs;

  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonAll = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius inputAll = BorderRadius.all(Radius.circular(input));
  static const BorderRadius dialogAll = BorderRadius.all(
    Radius.circular(dialog),
  );

  /// Sheets round only their top corners.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );

  /// A bar's data end is rounded; its baseline end stays square.
  static const BorderRadius barHorizontal = BorderRadius.horizontal(
    right: Radius.circular(chartBarCap),
  );

  static const BorderRadius barVertical = BorderRadius.vertical(
    top: Radius.circular(chartBarCap),
  );
}

/// Icon sizes. Four steps; resist adding more.
abstract final class AppIconSize {
  const AppIconSize._();

  /// 16 — inline with text.
  static const double sm = 16;

  /// 20 — the default, inside buttons and list rows.
  static const double md = 20;

  /// 24 — app bar and bottom navigation.
  static const double lg = 24;

  /// 32 — inside a category avatar.
  static const double xl = 32;

  /// 48 — the illustration in an empty state.
  static const double huge = 48;
}

/// Stroke widths for borders and chart marks.
abstract final class AppStroke {
  const AppStroke._();

  /// Hairline: borders, gridlines, dividers.
  static const double hairline = 1;

  /// Focus rings and selected outlines.
  static const double focus = 2;

  /// Chart lines. Thin enough to stay calm, thick enough to read.
  static const double chartLine = 2.5;

  /// Progress ring thickness.
  static const double ring = 8;
}
