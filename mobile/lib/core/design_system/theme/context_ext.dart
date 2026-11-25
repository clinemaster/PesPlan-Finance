import 'package:material_ui/material_ui.dart';

import 'finance_colors.dart';

/// Short, safe accessors for the design system.
///
/// Without these, every widget writes
/// `Theme.of(context).extension<FinanceColors>()!` — long enough that people
/// start passing colours down as constructor arguments instead, which is how
/// a design system quietly stops being used.
extension DesignSystemContext on BuildContext {
  /// Material colours: `context.colors.primary`.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Type scale: `context.text.bodyLarge`.
  TextTheme get text => Theme.of(this).textTheme;

  /// Finance semantics and validated chart palettes:
  /// `context.finance.incomeText`.
  ///
  /// Non-null by construction — both [ThemeData]s register the extension — so
  /// a failure here means someone built a `ThemeData` without it.
  FinanceColors get finance {
    final extension = Theme.of(this).extension<FinanceColors>();
    assert(
      extension != null,
      'FinanceColors missing from the theme. Build themes with AppTheme.light '
      'or AppTheme.dark, which register it.',
    );
    return extension ?? FinanceColors.light;
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// True when the user has enlarged text past ~130%, where tight horizontal
  /// layouts should stack instead of shrink.
  bool get isLargeTextScale =>
      MediaQuery.textScalerOf(this).scale(16) / 16 > 1.3;
}
