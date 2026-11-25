import 'package:material_ui/material_ui.dart';

import '../tokens/app_colors.dart';

/// Finance-specific colours, carried on the theme as a [ThemeExtension].
///
/// ## Why an extension rather than more entries in `ColorScheme`
///
/// Material's `ColorScheme` has slots for primary, error, surface and so on —
/// nothing for "money in", "money out", "set aside", or a validated chart
/// series. Forcing those into `tertiary` and `secondaryContainer` loses their
/// meaning at the call site, and the next developer cannot tell which slot
/// means income.
///
/// So they live here, named for what they mean, reachable as
/// `Theme.of(context).extension<FinanceColors>()!` — or more conveniently
/// `context.finance` (see `context_ext.dart`). Switching to dark mode swaps
/// the whole set in one place, and no widget needs to ask which theme is
/// active.
///
/// ## The mark / text pairing
///
/// Each semantic has a `mark` colour for fills, icons and chart marks, and a
/// `*Text` colour for anything read as text. They differ because the mark
/// values do not all reach 4.5:1 on white — see `app_colors.dart` for the
/// measured ratios. Using a mark value as a text colour is a bug.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.incomeText,
    required this.incomeSurface,
    required this.expense,
    required this.expenseText,
    required this.expenseSurface,
    required this.savings,
    required this.savingsText,
    required this.savingsSurface,
    required this.warning,
    required this.warningText,
    required this.warningSurface,
    required this.success,
    required this.successText,
    required this.successSurface,
    required this.info,
    required this.infoText,
    required this.infoSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.surfaceMuted,
    required this.chartSeries,
    required this.chartSeriesAllPairs,
    required this.chartSequential,
    required this.chartContext,
    required this.chartGrid,
    required this.chartAxis,
    required this.chartTrack,
    required this.cardShadow,
  });

  // Money in.
  final Color income;
  final Color incomeText;
  final Color incomeSurface;

  // Money out.
  final Color expense;
  final Color expenseText;
  final Color expenseSurface;

  // Money set aside.
  final Color savings;
  final Color savingsText;
  final Color savingsSurface;

  // Status.
  final Color warning;
  final Color warningText;
  final Color warningSurface;
  final Color success;
  final Color successText;
  final Color successSurface;
  final Color info;
  final Color infoText;
  final Color infoSurface;

  // Ink tiers.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Structure.
  final Color border;
  final Color borderStrong;
  final Color surfaceMuted;

  /// Validated series palette for bars and lines. Assigned in order, never
  /// cycled: a seventh series folds into "Other" rather than reusing slot 1.
  final List<Color> chartSeries;

  /// Validated series palette for donut/pie charts, where every segment is
  /// compared with every other. Capped at three for colour-vision safety.
  final List<Color> chartSeriesAllPairs;

  /// Single-hue ramp for magnitude.
  final List<Color> chartSequential;

  /// De-emphasised series: last period, target, baseline.
  final Color chartContext;

  final Color chartGrid;
  final Color chartAxis;
  final Color chartTrack;

  final List<BoxShadow> cardShadow;

  /// The colour an amount should be drawn in, given its sign.
  ///
  /// Centralised so no screen re-decides it. Zero is neutral — rendering a
  /// zero balance in red would read as a problem when it is not.
  Color amountColor(int minorUnits) {
    if (minorUnits > 0) return incomeText;
    if (minorUnits < 0) return expenseText;
    return textPrimary;
  }

  /// The series colour for index [i], folding anything past the palette into
  /// the context grey rather than inventing a hue.
  Color series(int i) => i < chartSeries.length ? chartSeries[i] : chartContext;

  static const FinanceColors light = FinanceColors(
    income: AppColors.income,
    incomeText: AppColors.incomeText,
    incomeSurface: AppColors.incomeSurface,
    expense: AppColors.expense,
    expenseText: AppColors.expenseText,
    expenseSurface: AppColors.expenseSurface,
    savings: AppColors.savings,
    savingsText: AppColors.savingsText,
    savingsSurface: AppColors.savingsSurface,
    warning: AppColors.warning,
    warningText: AppColors.warningText,
    warningSurface: AppColors.warningSurface,
    success: AppColors.success,
    successText: AppColors.successText,
    successSurface: AppColors.successSurface,
    info: AppColors.info,
    infoText: AppColors.infoText,
    infoSurface: AppColors.infoSurface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    textDisabled: AppColors.textDisabled,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    surfaceMuted: AppColors.surfaceMuted,
    chartSeries: AppColors.chartSeries,
    chartSeriesAllPairs: AppColors.chartSeriesAllPairs,
    chartSequential: AppColors.chartSequential,
    chartContext: AppColors.chartContext,
    chartGrid: AppColors.chartGrid,
    chartAxis: AppColors.chartAxis,
    chartTrack: AppColors.chartTrack,
    cardShadow: AppElevationRef.sm,
  );

  static const FinanceColors dark = FinanceColors(
    income: AppColors.darkIncome,
    incomeText: AppColors.darkIncomeText,
    incomeSurface: AppColors.darkIncomeSurface,
    expense: AppColors.darkExpense,
    expenseText: AppColors.darkExpenseText,
    expenseSurface: AppColors.darkExpenseSurface,
    savings: AppColors.darkSavings,
    savingsText: AppColors.darkSavingsText,
    savingsSurface: AppColors.darkSavingsSurface,
    warning: AppColors.darkWarning,
    warningText: AppColors.darkWarningText,
    warningSurface: AppColors.darkWarningSurface,
    success: AppColors.darkIncome,
    successText: AppColors.darkIncomeText,
    successSurface: AppColors.darkIncomeSurface,
    info: AppColors.darkPrimary,
    infoText: AppColors.darkPrimary,
    infoSurface: AppColors.darkPrimaryLight,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    textDisabled: AppColors.darkTextDisabled,
    border: AppColors.darkBorder,
    borderStrong: AppColors.darkBorderStrong,
    surfaceMuted: AppColors.darkSurfaceMuted,
    chartSeries: AppColors.chartSeriesDark,
    chartSeriesAllPairs: AppColors.chartSeriesAllPairs,
    chartSequential: AppColors.chartSequential,
    chartContext: AppColors.darkChartContext,
    chartGrid: AppColors.darkChartGrid,
    chartAxis: AppColors.darkChartAxis,
    chartTrack: AppColors.darkChartTrack,
    cardShadow: AppElevationRef.darkSm,
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeText,
    Color? incomeSurface,
    Color? expense,
    Color? expenseText,
    Color? expenseSurface,
    Color? savings,
    Color? savingsText,
    Color? savingsSurface,
    Color? warning,
    Color? warningText,
    Color? warningSurface,
    Color? success,
    Color? successText,
    Color? successSurface,
    Color? info,
    Color? infoText,
    Color? infoSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? border,
    Color? borderStrong,
    Color? surfaceMuted,
    List<Color>? chartSeries,
    List<Color>? chartSeriesAllPairs,
    List<Color>? chartSequential,
    Color? chartContext,
    Color? chartGrid,
    Color? chartAxis,
    Color? chartTrack,
    List<BoxShadow>? cardShadow,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      incomeText: incomeText ?? this.incomeText,
      incomeSurface: incomeSurface ?? this.incomeSurface,
      expense: expense ?? this.expense,
      expenseText: expenseText ?? this.expenseText,
      expenseSurface: expenseSurface ?? this.expenseSurface,
      savings: savings ?? this.savings,
      savingsText: savingsText ?? this.savingsText,
      savingsSurface: savingsSurface ?? this.savingsSurface,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      warningSurface: warningSurface ?? this.warningSurface,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successSurface: successSurface ?? this.successSurface,
      info: info ?? this.info,
      infoText: infoText ?? this.infoText,
      infoSurface: infoSurface ?? this.infoSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      chartSeries: chartSeries ?? this.chartSeries,
      chartSeriesAllPairs: chartSeriesAllPairs ?? this.chartSeriesAllPairs,
      chartSequential: chartSequential ?? this.chartSequential,
      chartContext: chartContext ?? this.chartContext,
      chartGrid: chartGrid ?? this.chartGrid,
      chartAxis: chartAxis ?? this.chartAxis,
      chartTrack: chartTrack ?? this.chartTrack,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) {
      if (a.length != b.length) return t < 0.5 ? a : b;
      return [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    }

    return FinanceColors(
      income: c(income, other.income),
      incomeText: c(incomeText, other.incomeText),
      incomeSurface: c(incomeSurface, other.incomeSurface),
      expense: c(expense, other.expense),
      expenseText: c(expenseText, other.expenseText),
      expenseSurface: c(expenseSurface, other.expenseSurface),
      savings: c(savings, other.savings),
      savingsText: c(savingsText, other.savingsText),
      savingsSurface: c(savingsSurface, other.savingsSurface),
      warning: c(warning, other.warning),
      warningText: c(warningText, other.warningText),
      warningSurface: c(warningSurface, other.warningSurface),
      success: c(success, other.success),
      successText: c(successText, other.successText),
      successSurface: c(successSurface, other.successSurface),
      info: c(info, other.info),
      infoText: c(infoText, other.infoText),
      infoSurface: c(infoSurface, other.infoSurface),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      chartSeries: l(chartSeries, other.chartSeries),
      chartSeriesAllPairs: l(chartSeriesAllPairs, other.chartSeriesAllPairs),
      chartSequential: l(chartSequential, other.chartSequential),
      chartContext: c(chartContext, other.chartContext),
      chartGrid: c(chartGrid, other.chartGrid),
      chartAxis: c(chartAxis, other.chartAxis),
      chartTrack: c(chartTrack, other.chartTrack),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Indirection so [FinanceColors] can stay `const` without importing the
/// elevation tokens into its own constructor signature.
abstract final class AppElevationRef {
  const AppElevationRef._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> darkSm = [
    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
}
