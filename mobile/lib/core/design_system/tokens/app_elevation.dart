import 'package:material_ui/material_ui.dart';

/// Elevation, expressed as shadows rather than Material elevation numbers.
///
/// A finance app should feel calm, and Material's default shadows are heavy
/// enough to make a list of cards look like a stack of physical receipts.
/// These are deliberately soft: a card is separated from the canvas mostly by
/// its white fill against the off-white background, with the shadow doing
/// only a little of the work.
///
/// Two shadows are layered at each level — a tight one for the contact edge
/// and a wider, fainter one for ambient depth. That reads as a lift rather
/// than a drop shadow.
abstract final class AppElevation {
  const AppElevation._();

  /// Flat. Default for a card in a list: the fill alone separates it.
  static const List<BoxShadow> none = [];

  /// Resting card.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// A raised surface: a summary card.
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 6)),
  ];

  /// Floating: a FAB or a menu.
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 12)),
  ];

  /// Modal: a bottom sheet or dialog above a scrim.
  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 16, offset: Offset(0, -2)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 40, offset: Offset(0, 16)),
  ];

  /// Scrim behind a modal.
  static const Color scrim = Color(0x660F172A);

  /// On a dark canvas a black shadow is invisible, so dark surfaces are
  /// separated by a border and a lighter fill instead. These exist so the API
  /// stays symmetric between themes.
  static const List<BoxShadow> darkSm = [
    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> darkMd = [
    BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 6)),
  ];
}
