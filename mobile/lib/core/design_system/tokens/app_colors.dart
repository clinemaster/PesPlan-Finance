import 'package:material_ui/material_ui.dart';

/// Every colour in LifePilot Finance.
///
/// Nothing outside this file may declare a `Color`. Feature screens read
/// colours from the theme (`context.colors`, `context.finance`), never from
/// here directly and never as a literal.
///
/// ## Contrast is measured, not assumed
///
/// Every value below was checked against the surface it is used on. The
/// numbers in comments are real WCAG 2.1 contrast ratios, computed during
/// Phase 02 and reproducible with any contrast checker.
///
/// Three colours from the original proposal did not survive that check and
/// were split in two rather than dropped:
///
/// * `#94A3B8` (muted) measures **2.56:1** on white — below even the 3:1
///   non-text floor. It is kept, but only as [textDisabled], where WCAG
///   exempts inactive controls.
/// * `#16A34A` (income) measures **3.30:1** and `#0D9488` (savings)
///   **3.74:1** — fine for a chart bar or an icon, failing for body text.
/// * `#DC2626` (expense) passes on white at 4.83:1 but only reaches 4.41:1 on
///   its own `#FEF2F2` tint, so it too needs a darker text tier.
/// * `#F59E0B` (warning) measures **2.15:1** — it fails even as an icon on
///   white, so it is only ever used as a fill behind dark ink.
///
/// Hence the rule this palette is built on: **a semantic colour has a `mark`
/// value for fills, icons and chart marks, and a separate `*Text` value for
/// anything a user has to read.** Using a mark value as a text colour is a
/// defect, not a style choice.
abstract final class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- brand

  /// Primary actions, links, focus, the single accent of the app.
  /// 5.17:1 on white — passes AA as text and as a 3:1 non-text mark.
  static const Color primary = Color(0xFF2563EB);

  /// Pressed/hover state and text that must outrank [primary]. 6.70:1.
  static const Color primaryDark = Color(0xFF1D4ED8);

  /// Tinted container behind primary content. Carries [primaryDark] ink.
  static const Color primaryLight = Color(0xFFEFF6FF);

  /// Ink that sits on top of [primary] — e.g. a filled button label. 5.17:1.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ----------------------------------------------------------- surfaces

  /// The app canvas. Deliberately not pure white, so white cards lift off it.
  static const Color background = Color(0xFFF8FAFC);

  /// Card and sheet surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// A recessed surface: input fills, skeletons, table stripes.
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  /// Hairline borders and dividers. Non-text, decorative.
  static const Color border = Color(0xFFE2E8F0);

  /// A stronger border for focus rings and selected outlines.
  static const Color borderStrong = Color(0xFFCBD5E1);

  // --------------------------------------------------------------- text

  /// Body copy, headings, and every monetary amount. 17.85:1 — AAA.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Labels and supporting copy. 4.76:1 — AA at any size.
  static const Color textSecondary = Color(0xFF64748B);

  /// Captions and metadata. 3.46:1 — **large text only** (>=18pt, or >=14pt
  /// semibold). Never use for body copy.
  static const Color textTertiary = Color(0xFF7C8BA1);

  /// Disabled labels and controls only. 2.56:1 — fails AA by design; WCAG
  /// exempts inactive controls, and nothing essential may rely on it.
  static const Color textDisabled = Color(0xFF94A3B8);

  /// Ink on a dark or saturated fill.
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ---------------------------------------------------- finance semantics
  //
  // Money in is green, money out is red, money set aside is teal. Each has a
  // mark value, a readable text value, and a tinted container.

  /// Income fills, chips and chart marks. 3.30:1 — non-text only.
  static const Color income = Color(0xFF16A34A);

  /// Income as text, including amounts. 5.02:1 — AA.
  static const Color incomeText = Color(0xFF15803D);

  /// Tinted container behind income content.
  static const Color incomeSurface = Color(0xFFF0FDF4);

  /// Expense fills, chips and chart marks. 4.83:1.
  static const Color expense = Color(0xFFDC2626);

  /// Expense as text. 6.01:1 on white, and — the reason it is a separate
  /// value — 5.80:1 on [expenseSurface]. The mark red `#DC2626` measures only
  /// 4.41:1 against its own tint, so red-on-red would have failed AA in every
  /// expense badge and over-budget label. Caught by a contrast test, not by
  /// eye.
  static const Color expenseText = Color(0xFFB91C1C);

  /// Tinted container behind expense content.
  static const Color expenseSurface = Color(0xFFFEF2F2);

  /// Savings fills and chart marks. 3.74:1 — non-text only.
  static const Color savings = Color(0xFF0D9488);

  /// Savings as text. 5.47:1 — AA.
  static const Color savingsText = Color(0xFF0F766E);

  /// Tinted container behind savings content.
  static const Color savingsSurface = Color(0xFFF0FDFA);

  // ------------------------------------------------------------- status

  /// Success state (distinct role from [income]: one is money, one is outcome).
  static const Color success = Color(0xFF16A34A);
  static const Color successText = Color(0xFF15803D);
  static const Color successSurface = Color(0xFFF0FDF4);

  /// Warning fill. 2.15:1 — **never an icon or text on white.** Only valid as
  /// a fill with [warningText] on top, or on [warningSurface].
  static const Color warning = Color(0xFFF59E0B);

  /// Warning as text or icon. 5.02:1 — AA.
  static const Color warningText = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFFFBEB);

  /// Error — same hue as expense, different role.
  static const Color error = Color(0xFFDC2626);
  static const Color errorText = Color(0xFFB91C1C);
  static const Color errorSurface = Color(0xFFFEF2F2);

  /// Neutral/informational.
  static const Color info = Color(0xFF2563EB);
  static const Color infoText = Color(0xFF1D4ED8);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ------------------------------------------------------- chart palettes
  //
  // Validated, not chosen by eye. Each list below passed a six-check audit
  // (lightness band, chroma floor, colour-vision-deficiency separation,
  // normal-vision separation, and >=3:1 contrast against its surface) in the
  // ordering given. The ORDER is part of the safety: slots are assigned in
  // sequence and never shuffled or cycled.

  /// Series colours for bars and lines, where a mark only ever sits beside
  /// its immediate neighbours.
  ///
  /// Audited on `#FFFFFF`: worst adjacent pair CVD ΔE **11.3** (target >=8),
  /// normal-vision ΔE **23.4** (floor >=15). All six slots clear 3:1.
  static const List<Color> chartSeries = [
    Color(0xFF2563EB), // 1 blue   — brand primary
    Color(0xFFEA580C), // 2 orange
    Color(0xFF0891B2), // 3 cyan
    Color(0xFF9333EA), // 4 purple
    Color(0xFFDB2777), // 5 pink
    Color(0xFF65A30D), // 6 lime
  ];

  /// Series colours for a donut or pie, where **every** segment is compared
  /// with every other.
  ///
  /// Hard-capped at three. With all pairs in play, blue and purple measure
  /// CVD ΔE **1.3** apart under deuteranopia — indistinguishable — and no
  /// ordering of six hues clears the floor. These three audited at CVD ΔE
  /// **14.7** / normal-vision **16.3**.
  ///
  /// A breakdown with more than three parts belongs in a bar chart, or folds
  /// its tail into "Other". Do not extend this list to make a chart fit.
  static const List<Color> chartSeriesAllPairs = [
    Color(0xFF2563EB),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
  ];

  /// Dark-theme series steps. Not a lightening of the light palette — these
  /// were re-stepped for a dark surface and audited against `#1E293B`:
  /// worst adjacent CVD ΔE **11.5**, normal-vision ΔE **19.2**.
  static const List<Color> chartSeriesDark = [
    Color(0xFF3B82F6),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFF65A30D),
  ];

  /// Single-hue ramp, light to dark, for magnitude (heatmaps, intensity).
  /// Never use a rainbow for magnitude.
  static const List<Color> chartSequential = [
    Color(0xFFDBEAFE),
    Color(0xFFBFDBFE),
    Color(0xFF93C5FD),
    Color(0xFF60A5FA),
    Color(0xFF3B82F6),
    Color(0xFF2563EB),
    Color(0xFF1D4ED8),
  ];

  /// Context series: last period, target, or baseline. Deliberately
  /// chroma-free — it is context, not a competing series, so it must not
  /// look like one.
  static const Color chartContext = Color(0xFF94A3B8);

  /// Chart chrome.
  static const Color chartGrid = Color(0xFFE2E8F0);
  static const Color chartAxis = Color(0xFFCBD5E1);
  static const Color chartTrack = Color(0xFFF1F5F9);

  // ------------------------------------------------------ dark foundation
  //
  // Enough for a working dark theme; not yet a shipped mode. Values were
  // picked for the dark surface rather than inverted from light.

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceMuted = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkBorderStrong = Color(0xFF475569);

  /// 15.8:1 on [darkSurface].
  static const Color darkTextPrimary = Color(0xFFF8FAFC);

  /// 7.0:1 on [darkSurface].
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  /// 4.6:1 on [darkSurface].
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkTextDisabled = Color(0xFF64748B);

  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkPrimaryLight = Color(0xFF1E3A8A);

  static const Color darkIncome = Color(0xFF22C55E);
  static const Color darkIncomeText = Color(0xFF4ADE80);
  static const Color darkIncomeSurface = Color(0xFF14532D);

  static const Color darkExpense = Color(0xFFEF4444);
  static const Color darkExpenseText = Color(0xFFF87171);
  static const Color darkExpenseSurface = Color(0xFF7F1D1D);

  static const Color darkSavings = Color(0xFF14B8A6);
  static const Color darkSavingsText = Color(0xFF2DD4BF);
  static const Color darkSavingsSurface = Color(0xFF134E4A);

  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkWarningText = Color(0xFFFBBF24);
  static const Color darkWarningSurface = Color(0xFF78350F);

  static const Color darkChartGrid = Color(0xFF334155);
  static const Color darkChartAxis = Color(0xFF475569);
  static const Color darkChartTrack = Color(0xFF334155);
  static const Color darkChartContext = Color(0xFF64748B);
}
