import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/report_data.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

/// Two years, side by side.
///
/// The years on offer are the ones that actually hold records, so nobody
/// can select two empty years and conclude the screen is broken.
class YearComparisonScreen extends ConsumerWidget {
  const YearComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(yearsWithDataProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Compare years',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: switch (years) {
          AsyncData(:final value) when value.length < 2 => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: EmptyState(
                icon: AppIcons.insights,
                title: 'Not enough history yet',
                message:
                    'A comparison needs records in two different years. '
                    'Come back once you have them.',
              ),
            ),
          ),
          AsyncData(:final value) => _Comparison(years: value),
          AsyncError(:final error) => ErrorState(
            message: 'We could not load your years. $error',
            onRetry: () => ref.invalidate(yearsWithDataProvider),
          ),
          _ => const LoadingState(message: 'Looking at your history'),
        },
      ),
    );
  }
}

class _Comparison extends ConsumerWidget {
  const _Comparison({required this.years});

  final List<int> years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defaults to the two most recent years with records, which is the
    // comparison almost everyone opens this screen for.
    final selection =
        ref.watch(comparisonYearsProvider) ??
        ComparisonYears(years[1], years[0]);

    final comparison = ref.watch(yearComparisonProvider(selection));
    final controller = ref.read(comparisonYearsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdown<int>(
                label: 'Earlier',
                items: years,
                value: selection.earlier,
                itemLabel: (year) => '$year',
                onChanged: (year) {
                  if (year != null) {
                    controller.select(
                      ComparisonYears(year, selection.later),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppDropdown<int>(
                label: 'Later',
                items: years,
                value: selection.later,
                itemLabel: (year) => '$year',
                onChanged: (year) {
                  if (year != null) {
                    controller.select(
                      ComparisonYears(selection.earlier, year),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        switch (comparison) {
          AsyncData() when selection.earlier == selection.later =>
            const _SameYearNote(),
          AsyncData(:final value) => _Lines(comparison: value),
          AsyncError(:final error) => ErrorState(
            message: 'We could not compare those years. $error',
            onRetry: () => ref.invalidate(yearComparisonProvider(selection)),
          ),
          _ => const LoadingState(message: 'Comparing'),
        },
      ],
    );
  }
}

class _SameYearNote extends StatelessWidget {
  const _SameYearNote();

  @override
  Widget build(BuildContext context) => const InProgressNote(
    message: 'Pick two different years to see a comparison.',
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.comparison});

  final YearComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!comparison.isTrustworthy) ...[
          InProgressNote(
            message:
                // The most common way a comparison misleads: a finished
                // year against a few months of another, presented as a
                // collapse in spending.
                'One of these years is incomplete, so the percentages '
                'below compare unequal stretches of time. Read them as a '
                'direction, not a measurement.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        for (final line in comparison.lines) ...[
          _LineCard(line: line, comparison: comparison),
          const SizedBox(height: AppSpacing.cardGap),
        ],

        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'By category', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              for (final line in comparison.categories) ...[
                _CategoryComparisonRow(line: line, comparison: comparison),
                if (line != comparison.categories.last) const AppDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.comparison});

  final ComparisonLine line;
  final YearComparison comparison;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.label,
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
              ),
              _ChangeBadge(line: line),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _YearFigure(
                  year: comparison.earlierYear,
                  amount: line.earlier,
                ),
              ),
              Icon(
                AppIcons.forward,
                size: AppIconSize.sm,
                color: finance.textTertiary,
              ),
              Expanded(
                child: _YearFigure(
                  year: comparison.laterYear,
                  amount: line.later,
                  isEmphasised: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearFigure extends StatelessWidget {
  const _YearFigure({
    required this.year,
    required this.amount,
    this.isEmphasised = false,
  });

  final int year;
  final Money amount;
  final bool isEmphasised;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$year',
          style: AppTypography.caption.copyWith(color: finance.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        MoneyText(
          amount,
          size: isEmphasised ? MoneySize.medium : MoneySize.small,
          colorBySign: false,
        ),
      ],
    );
  }
}

/// Up or down, and whether that is good news.
///
/// Direction alone is not meaning: spending up and income up are the same
/// arrow and opposite outcomes, so the colour comes from
/// [ComparisonLine.isFavourable] rather than from the sign.
class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.line});

  final ComparisonLine line;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    if (line.percentChange == null) {
      return Text(
        // No baseline to grow from. "Up 100%" from nothing is not a fact.
        line.isUnchanged ? 'No change' : 'New',
        style: AppTypography.caption.copyWith(color: finance.textTertiary),
      );
    }

    final percent = (line.percentChange! * 100).abs().round();
    final colour = line.isUnchanged
        ? finance.textSecondary
        : (line.isFavourable ? finance.incomeText : finance.expenseText);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          line.isUnchanged
              ? AppIcons.more
              : (line.hasIncreased
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
          size: AppIconSize.sm,
          color: colour,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          line.isUnchanged ? 'Same' : '$percent%',
          style: AppTypography.label.copyWith(color: colour),
        ),
      ],
    );
  }
}

class _CategoryComparisonRow extends StatelessWidget {
  const _CategoryComparisonRow({
    required this.line,
    required this.comparison,
  });

  final ComparisonLine line;
  final YearComparison comparison;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label:
          '${line.label}: ${comparison.earlierYear} '
          '${line.earlier.semanticLabel}, ${comparison.laterYear} '
          '${line.later.semanticLabel}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            CategoryIcon(category: line.label, size: AppIconSize.xl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: finance.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${line.earlier.format(abbreviate: true)} → '
                    '${line.later.format(abbreviate: true)}',
                    style: AppTypography.caption.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ChangeBadge(line: line),
          ],
        ),
      ),
    );
  }
}
