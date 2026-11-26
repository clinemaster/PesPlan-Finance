import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/report_data.dart';
import '../../domain/report_period.dart';

/// Which kind of window, as a row of chips.
///
/// All five visible rather than in a dropdown: the choice changes every
/// figure below it, so it should be readable without a tap.
class ReportKindSelector extends StatelessWidget {
  const ReportKindSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ReportPeriodKind selected;
  final ValueChanged<ReportPeriodKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReportPeriodKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final kind = ReportPeriodKind.values[index];
          final isSelected = kind == selected;
          final foreground = isSelected
              ? context.colors.onPrimary
              : finance.textSecondary;

          return Semantics(
            button: true,
            selected: isSelected,
            label: kind.label,
            excludeSemantics: true,
            child: Material(
              color: isSelected
                  ? context.colors.primary
                  : finance.surfaceMuted,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.pill),
              ),
              child: InkWell(
                onTap: () => onSelected(kind),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      kind.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The current window, with a step either side.
///
/// Forward is disabled rather than hidden at the present edge: a control
/// that vanishes reads as a bug, where a dimmed one says "there is
/// nothing that way".
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    required this.title,
    required this.subtitle,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      children: [
        AppIconButton(
          icon: AppIcons.back,
          tooltip: 'Previous period',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleCard.copyWith(
                  color: finance.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        AppIconButton(
          icon: AppIcons.forward,
          tooltip: 'Next period',
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// In, out and net for the window.
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({required this.data, super.key});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net movement',
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          MoneyText(data.net, size: MoneySize.large),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            // Repeated wherever a net appears. The app has no account
            // connection, so it can say what moved but never what is held.
            'Income minus expenses · not an account balance',
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Money in',
                  amount: data.income,
                  color: finance.incomeText,
                  icon: AppIcons.income,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Money out',
                  amount: data.expenses,
                  color: finance.expenseText,
                  icon: AppIcons.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final Money amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label: '$label ${amount.semanticLabel}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppIconSize.sm, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          MoneyText(
            amount,
            size: MoneySize.medium,
            colorBySign: false,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// The secondary figures, two per row.
class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.metrics, super.key});

  final List<ReportMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < metrics.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MetricCard(metric: metrics[i])),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  child: i + 1 < metrics.length
                      ? _MetricCard(metric: metrics[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: AppTypography.titleCard.copyWith(
                color: finance.textPrimary,
              ),
            ),
          ),
          if (metric.caption != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              metric.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spending by category, ranked.
///
/// Labelled horizontal bars rather than a donut: the design system caps a
/// donut at three coloured segments because its palette cannot keep more
/// apart under colour-vision deficiency, and a real month has seven
/// categories. One colour plus text scales, stays readable for everyone,
/// and never hides a label inside a short bar.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    required this.categories,
    required this.onCategoryTap,
    super.key,
  });

  final List<CategorySlice> categories;
  final void Function(CategorySlice slice) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    if (categories.isEmpty) {
      return AppCard(
        child: Text(
          'No spending in this period.',
          style: AppTypography.bodyMedium.copyWith(
            color: finance.textSecondary,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (final slice in categories) ...[
            _CategoryRow(slice: slice, onTap: () => onCategoryTap(slice)),
            if (slice != categories.last) const AppDivider(),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.slice, required this.onTap});

  final CategorySlice slice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      button: true,
      label:
          '${slice.label}, ${slice.amount.semanticLabel}, '
          '${slice.percent} percent of spending, '
          'rank ${slice.rank}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  CategoryIcon(category: slice.label, size: AppIconSize.xl),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: finance.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${slice.percent}% · '
                          '${slice.transactionCount} '
                          '${slice.transactionCount == 1 ? 'entry' : 'entries'}',
                          style: AppTypography.caption.copyWith(
                            color: finance.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MoneyText(
                    slice.amount,
                    size: MoneySize.small,
                    colorBySign: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(
                value: slice.share,
                color: context.colors.primary,
                semanticLabel: slice.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown where a window has not finished yet.
///
/// Without it a part-month sits next to a full one and looks like a
/// collapse in spending, which is the most common way a reporting screen
/// misleads.
class InProgressNote extends StatelessWidget {
  const InProgressNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: finance.infoSurface,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: AppIconSize.sm, color: finance.infoText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: finance.infoText),
            ),
          ),
        ],
      ),
    );
  }
}
