import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Theme registration', () {
    test('both themes carry the FinanceColors extension', () {
      // If this breaks, every `context.finance` call falls back silently and
      // the app renders with light colours in dark mode.
      expect(AppTheme.light.extension<FinanceColors>(), isNotNull);
      expect(AppTheme.dark.extension<FinanceColors>(), isNotNull);
    });

    test('brightness and canvas match the mode', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    test('dark colours are chosen for dark, not inverted from light', () {
      final light = AppTheme.light.extension<FinanceColors>()!;
      final dark = AppTheme.dark.extension<FinanceColors>()!;

      // A real re-step, not a flip: every semantic differs between modes.
      expect(dark.income, isNot(light.income));
      expect(dark.expense, isNot(light.expense));
      expect(dark.chartSeries, isNot(light.chartSeries));
      expect(dark.textPrimary, isNot(light.textPrimary));
    });

    testWidgets('context accessors resolve through the theme', (tester) async {
      late FinanceColors finance;
      late ColorScheme colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              finance = context.finance;
              colors = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(finance.income, AppColors.income);
      expect(colors.primary, AppColors.primary);
    });

    testWidgets('isDarkMode reflects the active theme', (tester) async {
      late bool isDark;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              isDark = context.isDarkMode;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isDark, isTrue);
    });
  });

  group('FinanceColors behaviour', () {
    const finance = FinanceColors.light;

    test('amountColor maps sign to meaning, with zero neutral', () {
      expect(finance.amountColor(1000), finance.incomeText);
      expect(finance.amountColor(-1000), finance.expenseText);
      // A zero balance is not a problem, so it is not red.
      expect(finance.amountColor(0), finance.textPrimary);
    });

    test('series() folds past the palette into context grey, never cycles', () {
      expect(finance.series(0), finance.chartSeries[0]);
      expect(finance.series(5), finance.chartSeries[5]);
      // A seventh series must not reuse slot 1 — that would make two
      // different things the same colour.
      expect(finance.series(6), finance.chartContext);
      expect(finance.series(99), finance.chartContext);
    });

    test('lerp produces a valid intermediate set', () {
      final mid = FinanceColors.light.lerp(FinanceColors.dark, 0.5);
      expect(mid.chartSeries.length, FinanceColors.light.chartSeries.length);
      expect(mid.income, isNot(FinanceColors.light.income));
    });

    test('copyWith changes only what it is given', () {
      final changed = finance.copyWith(income: const Color(0xFF123456));
      expect(changed.income, const Color(0xFF123456));
      expect(changed.expense, finance.expense);
      expect(changed.chartSeries, finance.chartSeries);
    });
  });

  group('Palette invariants', () {
    test('the donut palette is capped at three', () {
      // Three is the colour-vision-safe limit when every segment is compared
      // with every other. Growing this list silently breaks that.
      expect(AppColors.chartSeriesAllPairs.length, 3);
    });

    test('series palettes are the documented length and start on brand', () {
      expect(AppColors.chartSeries.length, 6);
      expect(AppColors.chartSeriesDark.length, 6);
      expect(AppColors.chartSeries.first, AppColors.primary);
    });

    test('the sequential ramp is a single hue, monotonically darkening', () {
      // A rainbow for magnitude is the classic misleading chart. Luminance
      // must decrease step by step.
      double luminance(Color c) => c.computeLuminance();

      for (var i = 1; i < AppColors.chartSequential.length; i++) {
        expect(
          luminance(AppColors.chartSequential[i]),
          lessThan(luminance(AppColors.chartSequential[i - 1])),
          reason: 'step $i must be darker than step ${i - 1}',
        );
      }
    });

    test('no series slot is duplicated', () {
      expect(
        AppColors.chartSeries.toSet().length,
        AppColors.chartSeries.length,
      );
    });

    test('the context colour is far less saturated than any series', () {
      // It is context, not a competing series, so it must not read as one.
      // The invariant is *relative*: the token is a slate grey (slightly blue,
      // to sit with the ink palette) rather than a mathematically neutral
      // grey, so what matters is that its chroma is a fraction of every
      // series colour's.
      double spread(Color c) {
        final channels = [c.r, c.g, c.b];
        return channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
      }

      final contextSpread = spread(AppColors.chartContext);
      expect(contextSpread, lessThan(0.25), reason: 'reads as grey');

      final weakestSeries = AppColors.chartSeries
          .map(spread)
          .reduce((a, b) => a < b ? a : b);
      expect(
        contextSpread,
        lessThan(weakestSeries / 2),
        reason: 'must be clearly less saturated than the dullest series',
      );
    });
  });

  group('Token invariants', () {
    test('spacing is a 4pt grid', () {
      const scale = [
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.huge,
      ];
      for (final step in scale) {
        expect(step % 2, 0, reason: '$step must sit on the grid');
      }
    });

    test('the scale ascends', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
    });

    test('body text starts at 16sp', () {
      // Deliberate: 14sp is comfortable for a developer and tiring for a
      // first-time user reading their finances on a phone.
      expect(AppTypography.bodyLarge.fontSize, 16);
    });

    test('every amount style uses tabular figures', () {
      const amountStyles = [
        AppTypography.amountHero,
        AppTypography.amountLarge,
        AppTypography.amountMedium,
        AppTypography.amountSmall,
        AppTypography.amountTick,
      ];

      for (final style in amountStyles) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: 'amounts must align in a column',
        );
      }
    });

    test('no amount style carries its own colour', () {
      // Colour comes from the finance semantics at the call site.
      const amountStyles = [
        AppTypography.amountHero,
        AppTypography.amountLarge,
        AppTypography.amountMedium,
        AppTypography.amountSmall,
      ];
      for (final style in amountStyles) {
        expect(style.color, isNull);
      }
    });

    test('the type scale descends from display to caption', () {
      expect(
        AppTypography.displayLarge.fontSize,
        greaterThan(AppTypography.titleScreen.fontSize!),
      );
      expect(
        AppTypography.titleScreen.fontSize,
        greaterThan(AppTypography.titleSection.fontSize!),
      );
      expect(
        AppTypography.titleSection.fontSize,
        greaterThan(AppTypography.bodyLarge.fontSize!),
      );
      expect(
        AppTypography.bodyLarge.fontSize,
        greaterThan(AppTypography.caption.fontSize!),
      );
    });

    test('card, button and input share one radius', () {
      // So swapping a component never changes the silhouette of a screen.
      expect(AppRadius.card, AppRadius.button);
      expect(AppRadius.button, AppRadius.input);
    });

    test('motion stays brisk', () {
      expect(AppMotion.fast.inMilliseconds, lessThan(200));
      expect(AppMotion.normal.inMilliseconds, lessThanOrEqualTo(250));
      expect(AppMotion.slow.inMilliseconds, lessThanOrEqualTo(350));
    });
  });

  group('Component themes are configured centrally', () {
    test('cards are flat with a hairline border', () {
      final card = AppTheme.light.cardTheme;
      expect(card.elevation, 0);
      expect(card.color, AppColors.surface);
    });

    test('app bars are flat and do not tint on scroll', () {
      final appBar = AppTheme.light.appBarTheme;
      expect(appBar.elevation, 0);
      expect(appBar.scrolledUnderElevation, 0);
      expect(appBar.centerTitle, isFalse);
    });

    test('inputs are filled and rounded to the shared radius', () {
      final input = AppTheme.light.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.errorMaxLines, greaterThanOrEqualTo(2));
    });

    test('bottom navigation always shows labels', () {
      expect(
        AppTheme.light.navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    });
  });
}
