import 'package:material_ui/material_ui.dart';

/// Durations and curves.
///
/// Motion in a finance app should confirm an action, never entertain. Short
/// durations and a single easing curve keep the app feeling responsive rather
/// than animated.
abstract final class AppMotion {
  const AppMotion._();

  /// 120ms — a press or colour change. Below ~100ms feels instant and loses
  /// the feedback; above ~200ms feels sluggish on a tap.
  static const Duration fast = Duration(milliseconds: 120);

  /// 200ms — the default: expand, fade, progress.
  static const Duration normal = Duration(milliseconds: 200);

  /// 300ms — sheets and dialogs entering.
  static const Duration slow = Duration(milliseconds: 300);

  /// 1200ms — one cycle of a skeleton shimmer.
  static const Duration shimmer = Duration(milliseconds: 1200);

  /// Standard easing for almost everything.
  static const Curve curve = Curves.easeOutCubic;

  /// Entering a screen or sheet.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving.
  static const Curve exit = Curves.easeInCubic;
}
