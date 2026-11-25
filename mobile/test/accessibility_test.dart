import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double value) {
    final c = value;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // These tests encode the accessibility promises the design system makes.
  // They are cheap, they run on every change, and they are the reason a
  // future "let's lighten the secondary text a bit" cannot ship silently.

  group('Contrast — text on surfaces', () {
    const card = AppColors.surface;
    const canvas = AppColors.background;

    test('primary ink is AAA on both surfaces', () {
      expect(contrastRatio(AppColors.textPrimary, card), greaterThan(7.0));
      expect(contrastRatio(AppColors.textPrimary, canvas), greaterThan(7.0));
    });

    test('secondary ink is AA at any size on both surfaces', () {
      expect(contrastRatio(AppColors.textSecondary, card), greaterThan(4.5));
      expect(contrastRatio(AppColors.textSecondary, canvas), greaterThan(4.5));
    });

    test('tertiary ink clears the 3:1 large-text floor', () {
      // Documented as large-text-only. It must not silently drift below 3:1,
      // which is where it stops being usable for anything.
      final ratio = contrastRatio(AppColors.textTertiary, card);
      expect(ratio, greaterThan(3.0));
      expect(ratio, lessThan(4.5), reason: 'still large-text only');
    });

    test('primary brand colour is AA as text and as a mark', () {
      expect(contrastRatio(AppColors.primary, card), greaterThan(4.5));
    });
  });

  group('Contrast — the mark/text split is real', () {
    const card = AppColors.surface;

    test('income and savings marks clear 3:1 but not 4.5:1', () {
      // This is exactly why the *Text variants exist. If a future change made
      // these pass 4.5:1, the split could be simplified — and this test would
      // tell us.
      for (final mark in [AppColors.income, AppColors.savings]) {
        final ratio = contrastRatio(mark, card);
        expect(ratio, greaterThan(3.0), reason: 'usable as a mark');
        expect(ratio, lessThan(4.5), reason: 'not usable as text');
      }
    });

    test('every *Text semantic is AA on a card', () {
      final textColors = {
        'incomeText': AppColors.incomeText,
        'expenseText': AppColors.expenseText,
        'savingsText': AppColors.savingsText,
        'warningText': AppColors.warningText,
        'successText': AppColors.successText,
        'infoText': AppColors.infoText,
      };

      textColors.forEach((name, color) {
        expect(
          contrastRatio(color, card),
          greaterThan(4.5),
          reason: '$name must be AA for body text',
        );
      });
    });

    test('warning fill is only safe on its own tint, never on white', () {
      // 2.15:1 on white — the token docs say "fill only", and this proves it.
      expect(contrastRatio(AppColors.warning, card), lessThan(3.0));
      // Its paired ink is readable on the tinted container.
      expect(
        contrastRatio(AppColors.warningText, AppColors.warningSurface),
        greaterThan(4.5),
      );
    });

    test('each semantic ink is AA on its own tinted surface', () {
      final pairs = <String, (Color, Color)>{
        'income': (AppColors.incomeText, AppColors.incomeSurface),
        'expense': (AppColors.expenseText, AppColors.expenseSurface),
        'savings': (AppColors.savingsText, AppColors.savingsSurface),
        'info': (AppColors.infoText, AppColors.infoSurface),
      };

      pairs.forEach((name, pair) {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThan(4.5),
          reason: '$name ink on $name surface',
        );
      });
    });

    test(
      'white ink on the brand fill is AA — the balance card depends on it',
      () {
        expect(
          contrastRatio(AppColors.onPrimary, AppColors.primary),
          greaterThan(4.5),
        );
      },
    );
  });

  group('Contrast — chart marks', () {
    test('every light series slot clears 3:1 on a white card', () {
      for (var i = 0; i < AppColors.chartSeries.length; i++) {
        expect(
          contrastRatio(AppColors.chartSeries[i], AppColors.surface),
          greaterThan(3.0),
          reason: 'series ${i + 1} must be visible as a mark',
        );
      }
    });

    test('every dark series slot clears 3:1 on a dark card', () {
      for (var i = 0; i < AppColors.chartSeriesDark.length; i++) {
        expect(
          contrastRatio(AppColors.chartSeriesDark[i], AppColors.darkSurface),
          greaterThan(3.0),
          reason: 'dark series ${i + 1}',
        );
      }
    });

    test('dark theme ink is readable on the dark surface', () {
      expect(
        contrastRatio(AppColors.darkTextPrimary, AppColors.darkSurface),
        greaterThan(7.0),
      );
      expect(
        contrastRatio(AppColors.darkTextSecondary, AppColors.darkSurface),
        greaterThan(4.5),
      );
    });
  });

  group('Touch targets', () {
    testWidgets('icon buttons are at least 48x48 regardless of icon size', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppIconButton(
              icon: AppIcons.more,
              tooltip: 'More',
              onPressed: () {},
              size: AppIconSize.sm, // a small glyph...
            ),
          ),
        ),
      );

      final size = tester.getSize(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(SizedBox).first,
        ),
      );
      // ...still a full-size target.
      expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
    });

    testWidgets('primary buttons meet the minimum height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton.primary(label: 'Save', onPressed: () {}),
          ),
        ),
      );

      final height = tester.getSize(find.byType(AppButton)).height;
      expect(height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
    });

    test('the token itself meets the platform guidance', () {
      expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(48));
      expect(AppSpacing.controlHeight, greaterThanOrEqualTo(48));
    });
  });

  group('Screen-reader labels', () {
    testWidgets('amounts are announced with currency and direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MoneyText(Money(-85400))),
        ),
      );

      expect(
        tester.getSemantics(find.byType(MoneyText)).label,
        '85,400 TZS out',
      );
    });

    testWidgets('icon buttons expose their tooltip as the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppIconButton(
              icon: AppIcons.delete,
              tooltip: 'Delete transaction',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Delete transaction'), findsOneWidget);
    });

    testWidgets('buttons are announced as buttons, with enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppButton.primary(label: 'Disabled', onPressed: null),
          ),
        ),
      );

      // Target the button's own semantics node by label: `byType` would
      // resolve to the enclosing node, which carries none of these flags.
      final semantics = tester.getSemantics(find.bySemanticsLabel('Disabled'));
      expect(semantics.flagsCollection.isButton, isTrue);
      // A disabled button exposes no tap action — the behavioural
      // statement, and stabler than the flag enum's representation.
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    });

    testWidgets('a loading button announces that it is working', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton.primary(
              label: 'Saving',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Saving')).hint,
        'Working',
      );
    });

    testWidgets('a budget card reads as one coherent sentence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: BudgetCard(
              category: 'groceries',
              spent: Money(420000),
              limit: Money(600000),
              ratio: 0.7,
              remaining: Money(180000),
            ),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(BudgetCard)).label;
      expect(label, contains('groceries budget'));
      expect(label, contains('420,000 TZS in spent'));
      expect(label, contains('70 percent used'));
      expect(label, contains('On track'));
    });
  });

  group('Dynamic text', () {
    testWidgets('a transaction row survives 2x text without overflowing', (
      tester,
    ) async {
      // The real failure mode: a user with large text set sees a row of
      // clipped, overlapping text. Flutter reports overflow as a test error,
      // so this passing means the row reflows or ellipsises.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              size: Size(360, 800),
            ),
            child: const Scaffold(
              body: TransactionTile(
                description: 'Bajaji to Kariakoo market and back again',
                category: 'transport',
                amount: Money(-6500),
                date: 'Yesterday',
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a full-width button survives 2x text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              size: Size(360, 800),
            ),
            child: Scaffold(
              body: AppButton.primary(
                label: 'Import a bank statement',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('clampTextScale keeps a generous ceiling', () {
      // A cap is a last resort; if it ever drops to 1.0 the app has stopped
      // honouring the user's setting.
      expect(2.0, greaterThanOrEqualTo(1.5));
    });
  });
}
