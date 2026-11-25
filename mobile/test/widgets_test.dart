import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Mounts a widget inside the real app theme, which is the only way these
/// components are ever used — `context.finance` would otherwise fall back.
Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('fires its callback when tapped', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        AppButton.primary(label: 'Save', onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('a null callback disables it', (tester) async {
      await pumpInApp(
        tester,
        const AppButton.primary(label: 'Save', onPressed: null),
      );

      // No exception, and nothing to tap through to.
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores taps while loading, and keeps its label', (
      tester,
    ) async {
      var taps = 0;
      await pumpInApp(
        tester,
        AppButton.primary(
          label: 'Saving',
          onPressed: () => taps++,
          isLoading: true,
        ),
      );

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(taps, 0, reason: 'a request already in flight must not refire');

      // The label stays visible so the button does not resize or lose meaning.
      expect(find.text('Saving'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('every variant keeps the same height', (tester) async {
      final heights = <double>[];

      for (final variant in AppButtonVariant.values) {
        await pumpInApp(
          tester,
          AppButton(label: 'Action', onPressed: () {}, variant: variant),
        );
        heights.add(tester.getSize(find.byType(AppButton)).height);
      }

      // Swapping a variant must never shift the layout around it.
      expect(heights.toSet().length, 1, reason: 'heights: $heights');
    });

    testWidgets('full width by default, hugging when told', (tester) async {
      // Align gives loose width constraints. A SingleChildScrollView would
      // hand the child a tight width and both variants would measure the
      // same, which says nothing about the widget.
      await pumpInApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: AppButton.primary(label: 'Wide', onPressed: () {}),
        ),
      );
      final wide = tester.getSize(find.byType(AppButton)).width;

      await pumpInApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: AppButton.primary(
            label: 'Narrow',
            onPressed: () {},
            isFullWidth: false,
          ),
        ),
      );
      final narrow = tester.getSize(find.byType(AppButton)).width;

      expect(wide, greaterThan(narrow));
    });

    testWidgets('AppIconButton fires and shows its tooltip', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        AppIconButton(
          icon: AppIcons.add,
          tooltip: 'Add transaction',
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.byType(AppIconButton));
      expect(taps, 1);
      expect(find.byTooltip('Add transaction'), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('is tappable when given a callback', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        AppCard(onTap: () => taps++, child: const Text('Tap me')),
      );

      await tester.tap(find.text('Tap me'));
      expect(taps, 1);
    });

    testWidgets('groups its contents under one semantic label', (tester) async {
      await pumpInApp(
        tester,
        const AppCard(
          semanticLabel: 'Balance summary',
          child: Text('TSh 2,450,000'),
        ),
      );

      expect(find.bySemanticsLabel('Balance summary'), findsOneWidget);
      // The child fragment is no longer announced separately.
      expect(find.bySemanticsLabel('TSh 2,450,000'), findsNothing);
    });
  });

  group('MoneyText', () {
    testWidgets('colours by sign, with zero neutral', (tester) async {
      await pumpInApp(
        tester,
        const Column(
          children: [
            MoneyText(Money(1000), key: Key('in')),
            MoneyText(Money(-1000), key: Key('out')),
            MoneyText(Money(0), key: Key('zero')),
          ],
        ),
      );

      Color colorOf(String key) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        );
        return text.style!.color!;
      }

      expect(colorOf('in'), AppColors.incomeText);
      expect(colorOf('out'), AppColors.expenseText);
      expect(colorOf('zero'), AppColors.textPrimary);
    });

    testWidgets('colorBySign off renders neutral ink', (tester) async {
      await pumpInApp(
        tester,
        const MoneyText(Money(-1000), colorBySign: false),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, AppColors.textPrimary);
    });

    testWidgets('renders TZS without a decimal part', (tester) async {
      await pumpInApp(tester, const MoneyText(Money(2450000)));
      expect(find.text('TSh 2,450,000'), findsOneWidget);
    });
  });

  group('Badges and status', () {
    testWidgets('each badge tone renders its label', (tester) async {
      await pumpInApp(
        tester,
        const Wrap(
          children: [
            AppBadge(label: 'Neutral'),
            AppBadge(label: 'In', tone: BadgeTone.income),
            AppBadge(label: 'Out', tone: BadgeTone.expense),
            AppBadge(label: 'Saved', tone: BadgeTone.savings),
            AppBadge(label: 'Careful', tone: BadgeTone.warning),
          ],
        ),
      );

      for (final label in ['Neutral', 'In', 'Out', 'Saved', 'Careful']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('status always pairs an icon with words', (tester) async {
      // The accessibility promise: never colour alone.
      for (final tone in StatusTone.values) {
        await pumpInApp(
          tester,
          StatusIndicator(label: 'State ${tone.name}', tone: tone),
        );

        expect(find.text('State ${tone.name}'), findsOneWidget);
        expect(
          find.byType(Icon),
          findsOneWidget,
          reason: '${tone.name} must ship an icon',
        );
      }
    });

    testWidgets('avatar derives initials from a name', (tester) async {
      await pumpInApp(tester, const AppAvatar(label: 'Alicia London'));
      expect(find.text('AL'), findsOneWidget);

      await pumpInApp(tester, const AppAvatar(label: 'Juma'));
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('category icon falls back for an unknown category', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const Row(
          children: [
            CategoryIcon(category: 'groceries'),
            CategoryIcon(category: 'not-a-real-category'),
          ],
        ),
      );

      // Both render; neither throws.
      expect(find.byType(CategoryIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      expect(AppIcons.forCategory('not-a-real-category'), AppIcons.other);
    });

    test('category lookup is case and whitespace insensitive', () {
      expect(AppIcons.forCategory(' Groceries '), AppIcons.groceries);
      expect(AppIcons.forCategory('TRANSPORT'), AppIcons.transport);
    });
  });

  group('Progress', () {
    testWidgets('reports its percentage to assistive tech', (tester) async {
      await pumpInApp(
        tester,
        const AppProgressBar(value: 0.42, semanticLabel: 'Groceries budget'),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel('Groceries budget'),
      );
      expect(node.value, '42%');
    });

    testWidgets('over-budget is still reported, not clamped away', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const AppProgressBar(value: 1.25, semanticLabel: 'Dining budget'),
      );

      // The fill clamps visually; the number must not lie.
      final node = tester.getSemantics(find.bySemanticsLabel('Dining budget'));
      expect(node.value, '125%');
    });

    testWidgets('ring renders its centre label', (tester) async {
      await pumpInApp(
        tester,
        const AppProgressRing(
          value: 0.62,
          centerLabel: '62%',
          centerCaption: 'of goal',
        ),
      );

      expect(find.text('62%'), findsOneWidget);
      expect(find.text('of goal'), findsOneWidget);
    });
  });

  group('Inputs', () {
    testWidgets('text field shows label, hint and error', (tester) async {
      await pumpInApp(
        tester,
        const AppTextField(
          label: 'Description',
          hint: 'e.g. Shoprite',
          error: 'Required',
          isRequired: true,
        ),
      );

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('e.g. Shoprite'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('amount field reports integer minor units for TZS', (
      tester,
    ) async {
      final reported = <int?>[];
      await pumpInApp(
        tester,
        AmountField(label: 'Amount', onChangedMinorUnits: reported.add),
      );

      await tester.enterText(find.byType(TextField), '12500');
      // Whole shillings: the digits are the minor units.
      expect(reported.last, 12500);
    });

    testWidgets('amount field scales a two-decimal currency', (tester) async {
      final reported = <int?>[];
      await pumpInApp(
        tester,
        AmountField(
          label: 'Amount',
          currency: Currency.usd,
          onChangedMinorUnits: reported.add,
        ),
      );

      await tester.enterText(find.byType(TextField), '12.34');
      expect(reported.last, 1234, reason: '12.34 USD is 1234 cents');

      await tester.enterText(find.byType(TextField), '7');
      expect(reported.last, 700, reason: 'a bare 7 is 7.00');

      await tester.enterText(find.byType(TextField), '0.5');
      expect(reported.last, 50, reason: '0.5 is 50 cents');
    });

    testWidgets('amount field rejects letters', (tester) async {
      final reported = <int?>[];
      await pumpInApp(
        tester,
        AmountField(label: 'Amount', onChangedMinorUnits: reported.add),
      );

      await tester.enterText(find.byType(TextField), '12abc5');
      expect(find.text('12abc5'), findsNothing);
      // Whatever survived the filter is a number, never null-from-garbage.
      expect(reported.last, isNotNull);
    });

    testWidgets('amount field reports null when emptied', (tester) async {
      final reported = <int?>[];
      await pumpInApp(
        tester,
        AmountField(label: 'Amount', onChangedMinorUnits: reported.add),
      );

      await tester.enterText(find.byType(TextField), '500');
      await tester.enterText(find.byType(TextField), '');
      // null is "no amount", distinct from 0 — the caller needs both.
      expect(reported.last, isNull);
    });

    testWidgets('TZS offers no decimal key', (tester) async {
      await pumpInApp(tester, const AmountField(label: 'Amount'));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('search field reveals a clear button only when filled', (
      tester,
    ) async {
      await pumpInApp(tester, const SearchField());

      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'tesco');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('dropdown renders options through itemLabel', (tester) async {
      await pumpInApp(
        tester,
        AppDropdown<String>(
          label: 'Category',
          items: const ['groceries', 'transport'],
          value: 'groceries',
          onChanged: (_) {},
          itemLabel: (item) => item.toUpperCase(),
        ),
      );

      expect(find.text('GROCERIES'), findsWidgets);
    });

    testWidgets('currency field lists the launch currencies', (tester) async {
      await pumpInApp(
        tester,
        CurrencyField(value: Currency.tzs, onChanged: (_) {}),
      );

      expect(
        find.textContaining('TZS'),
        findsWidgets,
        reason: 'TZS leads because Tanzania ships first',
      );
    });

    testWidgets('date field shows a placeholder until chosen', (tester) async {
      await pumpInApp(
        tester,
        DateField(label: 'Date', value: null, onChanged: (_) {}),
      );
      expect(find.text('Select a date'), findsOneWidget);

      await pumpInApp(
        tester,
        DateField(label: 'Date', value: '25 Nov 2026', onChanged: (_) {}),
      );
      expect(find.text('25 Nov 2026'), findsOneWidget);
    });
  });

  group('States', () {
    testWidgets('empty state offers one action', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        EmptyState(
          title: 'No transactions yet',
          message: 'Add your first one.',
          actionLabel: 'Add transaction',
          onAction: () => taps++,
        ),
      );

      expect(find.text('No transactions yet'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('error state retries', (tester) async {
      var retries = 0;
      await pumpInApp(
        tester,
        ErrorState(
          message: 'No internet connection.',
          onRetry: () => retries++,
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(retries, 1);
    });

    testWidgets('loading state announces itself', (tester) async {
      await pumpInApp(tester, const LoadingState(message: 'Loading'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsWidgets);
    });

    testWidgets('skeletons are hidden from assistive tech', (tester) async {
      await pumpInApp(tester, const SkeletonList(itemCount: 3));

      // A screen reader should hear "Loading", not a list of empty boxes.
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading'), findsWidgets);
    });

    testWidgets('skeleton is static when the OS asks to reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Skeleton(width: 100)),
          ),
        ),
      );

      // No AnimatedBuilder *inside the Skeleton* means no shimmer loop.
      expect(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Finance components', () {
    testWidgets('balance card renders the hero figure on the brand fill', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const BalanceCard(
          label: 'Available balance',
          balance: Money(2450000),
          caption: 'Across 2 accounts',
        ),
      );

      expect(find.text('TSh 2,450,000'), findsOneWidget);
      expect(find.text('Available balance'), findsOneWidget);
      expect(find.text('Across 2 accounts'), findsOneWidget);
    });

    testWidgets('summary cards render each kind', (tester) async {
      await pumpInApp(
        tester,
        const Column(
          children: [
            FinanceSummaryCard.income(
              label: 'Money in',
              amount: Money(3200000),
            ),
            FinanceSummaryCard.expense(
              label: 'Money out',
              amount: Money(1875500),
            ),
            FinanceSummaryCard.savings(
              label: 'Set aside',
              amount: Money(750000),
            ),
          ],
        ),
      );

      expect(find.byType(FinanceSummaryCard), findsNWidgets(3));
      expect(find.text('TSh 3,200,000'), findsOneWidget);
    });

    testWidgets('budget card states follow the ratio', (tester) async {
      Future<void> pumpBudget(double ratio) => pumpInApp(
        tester,
        BudgetCard(
          category: 'groceries',
          spent: const Money(420000),
          limit: const Money(600000),
          ratio: ratio,
          remaining: const Money(180000),
        ),
      );

      await pumpBudget(0.5);
      expect(find.text('On track'), findsOneWidget);

      await pumpBudget(0.85);
      expect(find.text('Close to limit'), findsOneWidget);

      await pumpBudget(1.3);
      expect(find.text('Over budget'), findsOneWidget);
      // The overage is spelled out rather than left to the user to subtract.
      expect(find.textContaining('over'), findsWidgets);
    });

    testWidgets('transaction tile shows sign as well as colour', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const TransactionTile(
          description: 'Shoprite Mlimani City',
          category: 'groceries',
          amount: Money(-85400),
          date: 'Today',
        ),
      );

      expect(find.text('Shoprite Mlimani City'), findsOneWidget);
      expect(find.text('groceries · Today'), findsOneWidget);
      // Direction survives in grayscale and for a colour-blind reader.
      expect(find.text('-TSh 85,400'), findsOneWidget);
    });
  });

  group('Charts', () {
    testWidgets('line chart renders with gaps in the data', (tester) async {
      await pumpInApp(
        tester,
        SizedBox(
          height: 200,
          child: AppLineChart(
            series: [
              ChartSeries(
                name: 'Spending',
                color: AppColors.chartSeries.first,
                points: const [
                  ChartPoint(label: 'Jan', value: 100),
                  ChartPoint(label: 'Feb', value: null),
                  ChartPoint(label: 'Mar', value: 300),
                ],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('charts survive empty and all-null series', (tester) async {
      await pumpInApp(
        tester,
        const SizedBox(height: 200, child: AppLineChart(series: [])),
      );
      expect(tester.takeException(), isNull);

      await pumpInApp(
        tester,
        SizedBox(
          height: 200,
          child: AppBarChart(
            series: [
              ChartSeries(
                name: 'Empty',
                color: AppColors.chartSeries.first,
                points: const [
                  ChartPoint(label: 'Jan', value: null),
                  ChartPoint(label: 'Feb', value: null),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('donut handles a zero total without dividing by zero', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        SizedBox(
          height: 180,
          child: AppDonutChart(
            slices: [
              ChartSlice(
                label: 'None',
                value: 0,
                color: AppColors.chartSeriesAllPairs.first,
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('chart container toggles to a table view', (tester) async {
      await pumpInApp(
        tester,
        ChartContainer(
          title: 'Spending',
          semanticLabel: 'Monthly spending',
          table: const Text('Jan TSh 100'),
          chart: const SizedBox(),
        ),
      );

      expect(find.text('Jan TSh 100'), findsNothing);

      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Every chart has a text equivalent — that is the accessibility
      // contract the container enforces for all of them.
      expect(find.text('Jan TSh 100'), findsOneWidget);
      expect(find.text('Chart'), findsOneWidget);
    });

    testWidgets('category breakdown lists names and amounts as text', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const CategoryBreakdown(
          rows: [
            CategoryBreakdownRow(
              category: 'Groceries',
              amount: Money(820000),
              ratio: 1,
            ),
            CategoryBreakdownRow(
              category: 'Transport',
              amount: Money(410000),
              ratio: 0.5,
            ),
          ],
        ),
      );

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('TSh 820,000'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('bottom nav reports selection changes', (tester) async {
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              items: const [
                AppNavItem(icon: AppIcons.home, label: 'Home'),
                AppNavItem(
                  icon: AppIcons.transactions,
                  label: 'Activity',
                  badgeCount: 3,
                ),
                AppNavItem(icon: AppIcons.budgets, label: 'Budgets'),
              ],
              currentIndex: selected,
              onChanged: (index) => selected = index,
            ),
          ),
        ),
      );

      // Labels are always visible, for users who do not recognise the icons.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Budgets'));
      expect(selected, 2);
    });

    testWidgets('app bar renders title, subtitle and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            appBar: AppTopBar(
              title: 'Transactions',
              subtitle: 'November 2026',
              actions: [
                AppIconButton(
                  icon: AppIcons.filter,
                  tooltip: 'Filter',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byTooltip('Filter'), findsOneWidget);
    });

    testWidgets('section header exposes an optional action', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        SectionHeader(
          title: 'Recent activity',
          subtitle: 'Last 7 days',
          actionLabel: 'See all',
          onAction: () => taps++,
        ),
      );

      expect(find.text('Recent activity'), findsOneWidget);
      await tester.tap(find.text('See all'));
      expect(taps, 1);
    });
  });

  group('Feedback', () {
    testWidgets('confirm dialog returns the user choice', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context,
                    title: 'Delete this transaction?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The consequence is stated, and the button names the verb.
      expect(find.text('Delete this transaction?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancelling returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context,
                    title: 'Discard?',
                    message: 'Your changes will be lost.',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('bottom sheet opens with a title and closes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton.primary(
                label: 'Open',
                onPressed: () => AppBottomSheet.show<void>(
                  context,
                  title: 'Choose a category',
                  child: const Text('Sheet body'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a category'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('snackbar shows one message at a time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  AppButton.primary(
                    label: 'First',
                    onPressed: () =>
                        AppSnackbar.success(context, 'Transaction saved'),
                  ),
                  AppButton.primary(
                    label: 'Second',
                    onPressed: () =>
                        AppSnackbar.error(context, 'Could not save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      expect(find.text('Transaction saved'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The newest message replaces the previous one rather than stacking.
      expect(find.text('Could not save'), findsOneWidget);
      expect(find.text('Transaction saved'), findsNothing);
    });
  });

  group('Dark theme', () {
    testWidgets('every component renders in dark without error', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const Column(
          children: [
            BalanceCard(label: 'Balance', balance: Money(2450000)),
            SizedBox(height: AppSpacing.md),
            FinanceSummaryCard.income(label: 'In', amount: Money(3200000)),
            SizedBox(height: AppSpacing.md),
            BudgetCard(
              category: 'dining',
              spent: Money(230000),
              limit: Money(150000),
              ratio: 1.53,
              remaining: Money(80000),
            ),
            SizedBox(height: AppSpacing.md),
            TransactionTile(
              description: 'Luku token',
              category: 'utilities',
              amount: Money(-45000),
            ),
            SizedBox(height: AppSpacing.md),
            AppBadge(label: 'Over', tone: BadgeTone.warning),
            StatusIndicator(label: 'Over budget', tone: StatusTone.error),
            AppProgressBar(value: 0.6),
          ],
        ),
        theme: AppTheme.dark,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('amount colours switch to the dark tier', (tester) async {
      await pumpInApp(
        tester,
        const MoneyText(Money(1000)),
        theme: AppTheme.dark,
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, AppColors.darkIncomeText);
    });
  });
}
