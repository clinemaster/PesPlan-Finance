/// The LifePilot Finance design system.
///
/// One import gives a screen the tokens, the theme accessors and every
/// reusable component:
///
/// ```dart
/// import 'package:lifepilot_finance/core/design_system/design_system.dart';
/// ```
///
/// Rules for every screen built on top of this:
///
/// 1. No literal `Color`, `TextStyle`, radius or padding value. Use tokens.
/// 2. No financial arithmetic. Amounts arrive computed; the UI formats them.
/// 3. Prefer a component here over a bespoke widget. If one is missing, add
///    it here rather than inline, so the next screen inherits it.
library;

export '../money/money.dart';
export '../widgets/widgets.dart';
export 'theme/app_theme.dart';
export 'theme/context_ext.dart';
export 'theme/finance_colors.dart';
export 'tokens/app_colors.dart';
export 'tokens/app_elevation.dart';
export 'tokens/app_icons.dart';
export 'tokens/app_motion.dart';
export 'tokens/app_shape.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_typography.dart';
