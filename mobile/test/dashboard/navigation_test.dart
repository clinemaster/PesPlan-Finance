import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/features/shell/presentation/main_shell.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('bottom navigation', () {
    testWidgets('offers the five destinations', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(MainShell.destinations, hasLength(5));

      for (final item in MainShell.destinations) {
        expect(
          find.text(item.label),
          findsWidgets,
          reason: '${item.label} is missing from the bar',
        );
      }
    });

    testWidgets('starts on Home', (tester) async {
      await DashboardHarness.pump(tester);

      expect(find.textContaining('Good morning, Amina'), findsOneWidget);
    });

    for (final (label, heading) in [
      ('Activity', 'Activity'),
      ('Budgets', 'Budgets'),
      ('Goals', 'Goals'),
      ('Assistant', 'Assistant'),
    ]) {
      testWidgets('$label opens its own screen', (tester) async {
        await DashboardHarness.pump(tester);

        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        expect(find.text(heading), findsWidgets);
        // The dashboard is gone, not merely scrolled off.
        expect(find.textContaining('Good morning, Amina'), findsNothing);
      });
    }

    testWidgets('the bar stays put while switching tabs', (tester) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.text('Goals').last);
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('returning to Home brings the dashboard back', (tester) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.text('Budgets').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Good morning, Amina'), findsOneWidget);
    });

    testWidgets('each tab keeps its place when you come back', (tester) async {
      // The reason this is a StatefulShellRoute: a user who scrolls the
      // dashboard, checks Budgets and returns should not be thrown back to
      // the top.
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Recent activity'));
      expect(find.textContaining('Good morning, Amina'), findsNothing);

      await tester.tap(find.text('Goals').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      // Still scrolled down where it was left.
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.textContaining('Good morning, Amina'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('opens over the shell and dismisses back', (tester) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.bySemanticsLabel('Profile and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Profile & settings'), findsOneWidget);

      // Pushed over the shell, so the bar is covered rather than beside it.
      expect(find.byType(AppBottomNav), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.textContaining('Good morning, Amina'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('shows the onboarding answers back to the user', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.bySemanticsLabel('Profile and settings'));
      await tester.pumpAndSettle();

      expect(find.text('Amina Hassan'), findsOneWidget);
      expect(find.textContaining('Tanzania · TZS'), findsOneWidget);
    });

    testWidgets('the empty-dashboard switch changes the dashboard', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);

      await tester.tap(find.bySemanticsLabel('Profile and settings'));
      await tester.pumpAndSettle();
      // The first switch in Review controls: there are two now that the
      // assistant has a failure control of its own.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Your money journey starts here.'), findsOneWidget);
    });
  });

  group('section links', () {
    testWidgets('View all on recent activity opens the Activity tab', (
      tester,
    ) async {
      await DashboardHarness.pump(tester);
      await DashboardHarness.scrollTo(tester, find.text('Recent activity'));

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Recent activity'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.text('View all'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsWidgets);
    });
  });
}
