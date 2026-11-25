import 'package:material_ui/material_ui.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_shape.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'finance_colors.dart';

/// The single source of styling for LifePilot Finance.
///
/// Component themes are configured here rather than at call sites, so a stock
/// Material widget already looks correct without being wrapped. A screen that
/// needs a custom look should be fixed here or use one of the components in
/// `core/widgets/` — never by passing one-off colours and paddings inline.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    finance: FinanceColors.light,
    scheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.savings,
      onSecondary: AppColors.textOnDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceMuted,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: AppColors.textOnDark,
      errorContainer: AppColors.errorSurface,
      onErrorContainer: AppColors.errorText,
    ),
    canvas: AppColors.background,
    cardShadow: AppElevation.sm,
  );

  /// Dark theme foundation.
  ///
  /// Complete enough to run and to review in the showcase, but not yet a
  /// shipped mode: the light theme is the launch design. The values are
  /// chosen *for* the dark surface rather than inverted from light, so
  /// enabling dark mode later is a switch, not a redesign.
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    finance: FinanceColors.dark,
    scheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.darkPrimaryLight,
      onPrimaryContainer: AppColors.darkTextPrimary,
      secondary: AppColors.darkSavings,
      onSecondary: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceMuted,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorderStrong,
      outlineVariant: AppColors.darkBorder,
      error: AppColors.darkExpense,
      onError: AppColors.darkBackground,
      errorContainer: AppColors.darkExpenseSurface,
      onErrorContainer: AppColors.darkExpenseText,
    ),
    canvas: AppColors.darkBackground,
    cardShadow: AppElevation.darkSm,
  );

  static ThemeData _build({
    required Brightness brightness,
    required FinanceColors finance,
    required ColorScheme scheme,
    required Color canvas,
    required List<BoxShadow> cardShadow,
  }) {
    final text = AppTypography.textTheme(
      finance.textPrimary,
      finance.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: text,
      fontFamily: AppTypography.fontFamily,
      extensions: <ThemeExtension<dynamic>>[finance],

      // A denser default than Material's, which is tuned for tablets.
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,

      // ------------------------------------------------------------ app bar
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: finance.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleScreen.copyWith(
          color: finance.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: finance.textPrimary,
          size: AppIconSize.lg,
        ),
      ),

      // -------------------------------------------------------------- cards
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: finance.border),
        ),
      ),

      // ------------------------------------------------------------ buttons
      // Height 52 and a 12px radius for every variant, so swapping a
      // variant never changes layout.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: finance.surfaceMuted,
          disabledForegroundColor: finance.textDisabled,
          minimumSize: const Size.fromHeight(AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppTypography.button,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: finance.surfaceMuted,
          disabledForegroundColor: finance.textDisabled,
          minimumSize: const Size.fromHeight(AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppTypography.button,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          disabledForegroundColor: finance.textDisabled,
          minimumSize: const Size.fromHeight(AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppTypography.button,
          side: BorderSide(color: finance.borderStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          disabledForegroundColor: finance.textDisabled,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: finance.textSecondary,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
        ),
      ),

      // ------------------------------------------------------------- inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? AppColors.surface
            : AppColors.darkSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: finance.textTertiary,
        ),
        labelStyle: AppTypography.label.copyWith(color: finance.textSecondary),
        floatingLabelStyle: AppTypography.label.copyWith(color: scheme.primary),
        helperStyle: AppTypography.caption.copyWith(
          color: finance.textSecondary,
        ),
        // Errors are never colour-alone: the message text carries the reason.
        errorStyle: AppTypography.caption.copyWith(color: scheme.error),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: finance.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: finance.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: scheme.primary, width: AppStroke.focus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: scheme.error, width: AppStroke.focus),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: finance.border),
        ),
      ),

      // ------------------------------------------------------------ surfaces
      dividerTheme: DividerThemeData(
        color: finance.border,
        thickness: AppStroke.hairline,
        space: AppStroke.hairline,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
        titleTextStyle: AppTypography.titleSection.copyWith(
          color: finance.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: finance.textSecondary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: finance.borderStrong,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: finance.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: brightness == Brightness.light
              ? AppColors.textOnDark
              : AppColors.darkBackground,
        ),
        actionTextColor: brightness == Brightness.light
            ? AppColors.darkPrimary
            : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: finance.textPrimary,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        textStyle: AppTypography.caption.copyWith(
          color: brightness == Brightness.light
              ? AppColors.textOnDark
              : AppColors.darkBackground,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        waitDuration: AppMotion.slow,
      ),

      // ---------------------------------------------------------- navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brightness == Brightness.light
            ? AppColors.primaryLight
            : AppColors.darkPrimaryLight,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSmall.copyWith(
            color: selected ? scheme.primary : finance.textSecondary,
            fontWeight: selected
                ? AppTypography.semibold
                : AppTypography.medium,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppIconSize.lg,
            color: selected ? scheme.primary : finance.textSecondary,
          );
        }),
      ),

      // -------------------------------------------------------------- chips
      chipTheme: ChipThemeData(
        backgroundColor: finance.surfaceMuted,
        selectedColor: brightness == Brightness.light
            ? AppColors.primaryLight
            : AppColors.darkPrimaryLight,
        labelStyle: AppTypography.labelSmall.copyWith(
          color: finance.textSecondary,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: finance.chartTrack,
        circularTrackColor: finance.chartTrack,
        linearMinHeight: AppSpacing.sm,
      ),

      iconTheme: IconThemeData(
        color: finance.textSecondary,
        size: AppIconSize.md,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        titleTextStyle: AppTypography.bodyLarge.copyWith(
          color: finance.textPrimary,
        ),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: finance.textSecondary,
        ),
        iconColor: finance.textSecondary,
        minVerticalPadding: AppSpacing.sm,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : finance.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Android's current forward-fade transition. iOS is left to the
      // platform default, which `material_ui` does not expose a builder for.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
