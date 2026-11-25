import 'package:material_ui/material_ui.dart';

import '../core/design_system/design_system.dart';
import 'showcase_data.dart';

/// Shared scroll frame for every showcase tab.
class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.screenV,
        AppSpacing.screenH,
        AppSpacing.huge,
      ),
      children: [
        for (final child in children) ...[
          child,
          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ],
    );
  }
}

/// A labelled swatch showing a token's colour, name and measured contrast.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name, this.note});

  final Color color;
  final String name;

  /// The measured contrast ratio and its permitted use.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: finance.border),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.bodyMedium.copyWith(
                  color: finance.textPrimary,
                  fontWeight: AppTypography.medium,
                ),
              ),
              Text(
                // Hex is shown so a reviewer can check a value against the
                // token file without reading code.
                '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}'
                '${note == null ? '' : '  ·  $note'}',
                style: AppTypography.caption.copyWith(
                  color: finance.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- 1. colour

class ColourSection extends StatelessWidget {
  const ColourSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return _Section(
      children: [
        const SectionHeader(
          title: 'Brand',
          subtitle: 'One accent. Everything else is ink and surface.',
        ),
        AppCard(
          child: Column(
            children: [
              _Swatch(
                color: context.colors.primary,
                name: 'primary',
                note: '5.17:1 — AA text',
              ),
              const AppDivider(),
              _Swatch(
                color: AppColors.primaryDark,
                name: 'primaryDark',
                note: '6.70:1 — pressed, links',
              ),
              const AppDivider(),
              _Swatch(
                color: AppColors.primaryLight,
                name: 'primaryLight',
                note: 'container only',
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Finance semantics',
          subtitle:
              'Each has a mark colour and a readable text colour. '
              'The pair exists because the mark values do not all reach '
              '4.5:1 on white.',
        ),
        AppCard(
          child: Column(
            children: [
              _Swatch(
                color: finance.income,
                name: 'income (mark)',
                note: '3.30:1 — fills and icons only',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.incomeText,
                name: 'incomeText',
                note: '5.02:1 — AA, use for amounts',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.expense,
                name: 'expense (mark)',
                note: '4.83:1 on white, 4.41:1 on its tint — mark only',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.expenseText,
                name: 'expenseText',
                note: '6.01:1 — AA on white and on the tint',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.savings,
                name: 'savings (mark)',
                note: '3.74:1 — fills only',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.savingsText,
                name: 'savingsText',
                note: '5.47:1 — AA',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.warning,
                name: 'warning (fill)',
                note: '2.15:1 — never text or an icon on white',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.warningText,
                name: 'warningText',
                note: '5.02:1 — AA',
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Ink',
          subtitle: 'Four tiers. The fourth is for disabled controls only.',
        ),
        AppCard(
          child: Column(
            children: [
              _Swatch(
                color: finance.textPrimary,
                name: 'textPrimary',
                note: '17.85:1 — AAA',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.textSecondary,
                name: 'textSecondary',
                note: '4.76:1 — AA any size',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.textTertiary,
                name: 'textTertiary',
                note: '3.46:1 — large text only',
              ),
              const AppDivider(),
              _Swatch(
                color: finance.textDisabled,
                name: 'textDisabled',
                note: '2.56:1 — disabled controls only',
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Chart series',
          subtitle:
              'Validated, not chosen by eye. Worst adjacent pair: '
              'colour-vision ΔE 11.3, normal vision 23.4. Assigned in order, '
              'never cycled.',
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < finance.chartSeries.length; i++) ...[
                if (i > 0) const AppDivider(),
                _Swatch(
                  color: finance.chartSeries[i],
                  name: 'series ${i + 1}',
                  note: i < 3 ? 'donut-safe' : 'bars and lines only',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- 2. type

class TypeSection extends StatelessWidget {
  const TypeSection({super.key});

  Widget _specimen(
    BuildContext context,
    String name,
    TextStyle style,
    String sample,
  ) {
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · ${style.fontSize!.round()}sp · w${style.fontWeight!.value}',
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sample,
            style: style.copyWith(color: finance.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      children: [
        const SectionHeader(
          title: 'Scale',
          subtitle:
              'Body starts at 16sp. Everything scales with the '
              'platform text-size setting.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _specimen(
                context,
                'displayLarge',
                AppTypography.displayLarge,
                'Your money',
              ),
              _specimen(
                context,
                'titleScreen',
                AppTypography.titleScreen,
                'Spending this month',
              ),
              _specimen(
                context,
                'titleSection',
                AppTypography.titleSection,
                'Recent activity',
              ),
              _specimen(
                context,
                'titleCard',
                AppTypography.titleCard,
                'Groceries budget',
              ),
              _specimen(
                context,
                'bodyLarge',
                AppTypography.bodyLarge,
                'Track every shilling without the spreadsheet.',
              ),
              _specimen(
                context,
                'bodyMedium',
                AppTypography.bodyMedium,
                'Track every shilling without the spreadsheet.',
              ),
              _specimen(context, 'label', AppTypography.label, 'Amount'),
              _specimen(
                context,
                'caption',
                AppTypography.caption,
                'Updated 2 minutes ago',
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Amounts',
          subtitle:
              'Tabular figures, so digits line up in a column and a '
              'changing balance does not jitter.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _specimen(
                context,
                'amountHero',
                AppTypography.amountHero,
                'TSh 2,450,000',
              ),
              _specimen(
                context,
                'amountLarge',
                AppTypography.amountLarge,
                'TSh 1,875,500',
              ),
              _specimen(
                context,
                'amountMedium',
                AppTypography.amountMedium,
                'TSh 85,400',
              ),
              _specimen(
                context,
                'amountSmall',
                AppTypography.amountSmall,
                'TSh 6,500',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Alignment check — every row uses tabular figures:',
                style: AppTypography.caption.copyWith(
                  color: context.finance.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Digits of differing widths, right-aligned: proof the columns
              // line up rather than drifting.
              for (final value in [111_111, 2_450_000, 85_400, 999_999])
                Align(
                  alignment: Alignment.centerRight,
                  child: MoneyText(
                    Money(value),
                    size: MoneySize.medium,
                    colorBySign: false,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- 3. components

class ComponentsSection extends StatefulWidget {
  const ComponentsSection({super.key});

  @override
  State<ComponentsSection> createState() => _ComponentsSectionState();
}

class _ComponentsSectionState extends State<ComponentsSection> {
  Currency _currency = Currency.tzs;
  String? _amountError;

  @override
  Widget build(BuildContext context) {
    return _Section(
      children: [
        const SectionHeader(
          title: 'Buttons',
          subtitle:
              'One widget, six weights. Same height and radius, so '
              'swapping a variant never changes layout.',
        ),
        AppCard(
          child: Column(
            children: [
              AppButton.primary(label: 'Add transaction', onPressed: () {}),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(label: 'Set a budget', onPressed: () {}),
              const SizedBox(height: AppSpacing.md),
              AppButton.outlined(
                label: 'Import statement',
                onPressed: () {},
                icon: AppIcons.upload,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.destructive(
                label: 'Delete transaction',
                onPressed: () {},
                icon: AppIcons.delete,
              ),
              const SizedBox(height: AppSpacing.md),
              const AppButton.primary(label: 'Disabled', onPressed: null),
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(
                label: 'Saving',
                onPressed: () {},
                isLoading: true,
              ),
              const AppDivider(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AppButton.text(label: 'Skip', onPressed: () {}),
                  AppButton.primary(
                    label: 'Small',
                    onPressed: () {},
                    size: AppButtonSize.small,
                    isFullWidth: false,
                  ),
                  AppIconButton(
                    icon: AppIcons.more,
                    tooltip: 'More options',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Inputs',
          subtitle:
              'Labels sit above the field, so they stay readable at any '
              'text size.',
        ),
        AppCard(
          child: Column(
            children: [
              const AppTextField(
                label: 'Description',
                hint: 'e.g. Shoprite Mlimani City',
                isRequired: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AmountField(
                label: 'Amount',
                currency: _currency,
                error: _amountError,
                helper: _currency.decimalDigits == 0
                    ? 'Whole shillings — TZS has no subunit'
                    : null,
                onChangedMinorUnits: (minorUnits) => setState(() {
                  _amountError = minorUnits == null || minorUnits == 0
                      ? 'Enter an amount greater than zero'
                      : null;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              CurrencyField(
                value: _currency,
                onChanged: (next) => setState(() {
                  if (next != null) _currency = next;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              DateField(
                label: 'Date',
                value: '25 November 2026',
                onChanged: (_) {},
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Reference',
                hint: 'Optional',
                error: 'This reference is already used',
              ),
              const SizedBox(height: AppSpacing.lg),
              const SearchField(hint: 'Search transactions'),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Badges and status',
          subtitle:
              'Status is colour, icon and words together — never colour '
              'alone.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  const AppBadge(label: 'Groceries'),
                  const AppBadge(label: 'Income', tone: BadgeTone.income),
                  const AppBadge(label: 'Expense', tone: BadgeTone.expense),
                  const AppBadge(label: 'Savings', tone: BadgeTone.savings),
                  const AppBadge(
                    label: 'Over budget',
                    tone: BadgeTone.warning,
                    icon: AppIcons.warning,
                  ),
                  const AppBadge(label: '3 new', tone: BadgeTone.primary),
                ],
              ),
              const AppDivider(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  const StatusIndicator(
                    label: 'On track',
                    tone: StatusTone.success,
                  ),
                  const StatusIndicator(
                    label: 'Close to limit',
                    tone: StatusTone.warning,
                  ),
                  const StatusIndicator(
                    label: 'Over budget',
                    tone: StatusTone.error,
                  ),
                  const StatusIndicator(
                    label: 'Syncing',
                    tone: StatusTone.pending,
                  ),
                ],
              ),
              const AppDivider(height: AppSpacing.xxl),
              Row(
                children: [
                  const AppAvatar(label: 'Alicia London'),
                  const SizedBox(width: AppSpacing.md),
                  const CategoryIcon(category: 'groceries'),
                  const SizedBox(width: AppSpacing.md),
                  const CategoryIcon(category: 'transport'),
                  const SizedBox(width: AppSpacing.md),
                  const CategoryIcon(category: 'utilities'),
                  const SizedBox(width: AppSpacing.md),
                  const CategoryIcon(category: 'unknown-category'),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Progress',
          subtitle:
              'The fill carries severity; the track is a tint of the '
              'same hue.',
        ),
        AppCard(
          child: Column(
            children: [
              const AppProgressBar(value: 0.35, semanticLabel: 'Comfortable'),
              const SizedBox(height: AppSpacing.lg),
              const AppProgressBar(value: 0.84, semanticLabel: 'Close'),
              const SizedBox(height: AppSpacing.lg),
              const AppProgressBar(value: 1.25, semanticLabel: 'Over'),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const AppProgressRing(
                    value: 0.62,
                    centerLabel: '62%',
                    centerCaption: 'of goal',
                    semanticLabel: 'Savings goal progress',
                  ),
                  const AppProgressRing(
                    value: 1.1,
                    size: 80,
                    centerLabel: '110%',
                    centerCaption: 'of budget',
                    semanticLabel: 'Budget used',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Overlays'),
        AppCard(
          child: Column(
            children: [
              AppButton.outlined(
                label: 'Show confirm dialog',
                onPressed: () => AppDialog.confirm(
                  context,
                  title: 'Delete this transaction?',
                  message:
                      'This permanently removes the TSh 85,400 Shoprite '
                      'transaction. This cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                  icon: AppIcons.delete,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.outlined(
                label: 'Show bottom sheet',
                onPressed: () => AppBottomSheet.show<void>(
                  context,
                  title: 'Choose a category',
                  child: Column(
                    children: [
                      for (final category in [
                        'groceries',
                        'transport',
                        'utilities',
                      ])
                        ListTile(
                          leading: CategoryIcon(category: category, size: 36),
                          title: Text(category),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.outlined(
                label: 'Show snackbar',
                onPressed: () =>
                    AppSnackbar.success(context, 'Transaction saved'),
              ),
              const SizedBox(height: AppSpacing.md),
              Tooltip(
                message: 'Transfers between your own accounts are excluded',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Long-press for a tooltip',
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.finance.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      AppIcons.info,
                      size: AppIconSize.sm,
                      color: context.finance.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'States',
          subtitle: 'Empty, error and loading are three different facts.',
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: EmptyState(
            title: 'No transactions yet',
            message:
                'Add your first transaction and LifePilot will start '
                'showing where your money goes.',
            icon: AppIcons.transactions,
            actionLabel: 'Add transaction',
            onAction: () {},
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ErrorState(
            message:
                'No internet connection. Check your connection and try '
                'again.',
            onRetry: () {},
          ),
        ),
        const AppCard(
          padding: EdgeInsets.zero,
          child: LoadingState(message: 'Loading your transactions'),
        ),
        const AppCard(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: SkeletonList(itemCount: 3),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 4. finance

class FinanceSection extends StatelessWidget {
  const FinanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _Section(
      children: [
        const SectionHeader(
          title: 'Balance',
          subtitle: 'One hero figure per screen.',
        ),
        const BalanceCard(
          label: 'Available balance',
          balance: ShowcaseData.balance,
          caption: 'Across 2 accounts · updated just now',
        ),
        const SectionHeader(title: 'Summary cards'),
        Row(
          children: [
            const Expanded(
              child: FinanceSummaryCard.income(
                label: 'Money in',
                amount: ShowcaseData.income,
                caption: 'This month',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FinanceSummaryCard.expense(
                label: 'Money out',
                amount: Money(ShowcaseData.expenses.minorUnits.abs()),
                caption: 'This month',
              ),
            ),
          ],
        ),
        const SizedBox(height: 0),
        Row(
          children: [
            const Expanded(
              child: FinanceSummaryCard.savings(
                label: 'Set aside',
                amount: ShowcaseData.savings,
                caption: '3 goals',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: FinanceSummaryCard(
                label: 'Net this month',
                amount: Money(1_324_500),
                kind: FinanceKind.neutral,
                caption: 'Transfers excluded',
              ),
            ),
          ],
        ),
        const SectionHeader(
          title: 'Budgets',
          subtitle: 'One of each state: on track, close, over.',
        ),
        // One child, so the group gets the section gap once and the cards
        // sit at the intended 12px card gap from each other.
        Column(
          children: [
            for (var i = 0; i < ShowcaseData.budgets.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.cardGap),
              BudgetCard(
                category: ShowcaseData.budgets[i].category,
                spent: ShowcaseData.budgets[i].spent,
                limit: ShowcaseData.budgets[i].limit,
                ratio: ShowcaseData.budgets[i].ratio,
                remaining: ShowcaseData.budgets[i].remaining,
                onTap: () {},
              ),
            ],
          ],
        ),
        const SectionHeader(
          title: 'Transactions',
          subtitle: 'Rows on a shared card, not fifty bordered cards.',
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < ShowcaseData.transactions.length; i++) ...[
                if (i > 0) const AppDivider(height: 1, indent: AppSpacing.lg),
                TransactionTile(
                  description: ShowcaseData.transactions[i].description,
                  category: ShowcaseData.transactions[i].category,
                  amount: ShowcaseData.transactions[i].amount,
                  date: ShowcaseData.transactions[i].date,
                  onTap: () {},
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- 5. charts

class ChartsSection extends StatelessWidget {
  const ChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return _Section(
      children: [
        ChartContainer(
          title: 'Spending trend',
          subtitle:
              'Aug and Dec have no records — the line breaks rather '
              'than dropping to zero',
          semanticLabel:
              'Monthly spending for the year. '
              'Use the table view for exact values.',
          height: 200,
          table: _placeholderTable(context),
          chart: AppLineChart(
            series: [
              ChartSeries(
                name: 'Spending',
                points: ShowcaseData.monthlySpend,
                color: finance.chartSeries[1],
              ),
            ],
          ),
        ),
        ChartContainer(
          title: 'Income vs spending',
          subtitle: 'Two series, one shared axis — never a second y-scale',
          semanticLabel: 'Monthly income compared with spending.',
          height: 200,
          legend: Row(
            children: [
              ChartLegendItem(
                color: finance.chartSeries[0],
                label: 'Income',
                isLine: true,
              ),
              const SizedBox(width: AppSpacing.lg),
              ChartLegendItem(
                color: finance.chartSeries[1],
                label: 'Spending',
                isLine: true,
              ),
            ],
          ),
          chart: AppLineChart(
            showArea: false,
            series: [
              ChartSeries(
                name: 'Income',
                points: ShowcaseData.monthlyIncome,
                color: finance.chartSeries[0],
              ),
              ChartSeries(
                name: 'Spending',
                points: ShowcaseData.monthlySpend,
                color: finance.chartSeries[1],
              ),
            ],
          ),
        ),
        ChartContainer(
          title: 'Weekly spending',
          subtitle: 'One series, one colour — the peak is labelled',
          semanticLabel: 'Spending for each of the last six weeks.',
          height: 190,
          chart: AppBarChart(
            series: [
              ChartSeries(
                name: 'Spending',
                points: ShowcaseData.weeklySpend,
                color: finance.chartSeries[0],
              ),
            ],
          ),
        ),
        ChartContainer(
          title: 'Where it went',
          subtitle:
              'Three colours plus Other — the colour-vision-safe limit '
              'for a donut',
          semanticLabel: 'Share of spending by category.',
          height: 190,
          legend: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              ChartLegendItem(
                color: finance.chartSeriesAllPairs[0],
                label: 'Groceries',
              ),
              ChartLegendItem(
                color: finance.chartSeriesAllPairs[1],
                label: 'Transport',
              ),
              ChartLegendItem(
                color: finance.chartSeriesAllPairs[2],
                label: 'Utilities',
              ),
              ChartLegendItem(color: finance.chartContext, label: 'Other'),
            ],
          ),
          chart: AppDonutChart(
            centerLabel: 'TSh 1.9M',
            centerCaption: 'this month',
            slices: [
              ChartSlice(
                label: 'Groceries',
                value: 820_000,
                color: finance.chartSeriesAllPairs[0],
              ),
              ChartSlice(
                label: 'Transport',
                value: 410_000,
                color: finance.chartSeriesAllPairs[1],
              ),
              ChartSlice(
                label: 'Utilities',
                value: 365_000,
                color: finance.chartSeriesAllPairs[2],
              ),
              ChartSlice(
                label: 'Other',
                value: 280_500,
                color: finance.chartContext,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Category breakdown',
                subtitle:
                    'The preferred form for many categories: one '
                    'colour, with names and amounts as real text',
              ),
              const SizedBox(height: AppSpacing.md),
              CategoryBreakdown(
                rows: [
                  const CategoryBreakdownRow(
                    category: 'Groceries',
                    amount: Money(820_000),
                    ratio: 1,
                  ),
                  const CategoryBreakdownRow(
                    category: 'Transport',
                    amount: Money(410_000),
                    ratio: 0.5,
                  ),
                  const CategoryBreakdownRow(
                    category: 'Utilities',
                    amount: Money(365_000),
                    ratio: 0.445,
                  ),
                  const CategoryBreakdownRow(
                    category: 'Airtime',
                    amount: Money(120_000),
                    ratio: 0.146,
                  ),
                  const CategoryBreakdownRow(
                    category: 'Dining',
                    amount: Money(98_000),
                    ratio: 0.12,
                  ),
                  const CategoryBreakdownRow(
                    category: 'Other',
                    amount: Money(62_500),
                    ratio: 0.076,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The text equivalent a chart's "Table" toggle reveals.
  Widget _placeholderTable(BuildContext context) {
    final finance = context.finance;

    return Column(
      children: [
        for (final point in ShowcaseData.monthlySpend)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  point.label,
                  style: AppTypography.bodySmall.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
                if (point.value == null)
                  Text(
                    'No records',
                    style: AppTypography.bodySmall.copyWith(
                      color: finance.textTertiary,
                    ),
                  )
                else
                  MoneyText(
                    Money(point.value!),
                    size: MoneySize.small,
                    colorBySign: false,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
