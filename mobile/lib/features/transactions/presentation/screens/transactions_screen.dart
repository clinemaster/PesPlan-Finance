import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../domain/date_labels.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_view.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/transactions_summary_strip.dart';

/// The transaction history.
///
/// Search and the two type chips live on the screen because they are used
/// constantly; everything else is a tap away in the filter sheet. The
/// summary describes whatever is currently listed, so narrowing the list
/// answers "what did Food cost me" without a separate report.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final filterController = ref.read(transactionFilterProvider.notifier);
    final listing = ref.watch(transactionListProvider);
    final finance = context.finance;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Transactions',
        actions: [
          AppIconButton(
            icon: AppIcons.filter,
            tooltip: filter.activeCount == 0
                ? 'Filter'
                : 'Filter (${filter.activeCount} active)',
            // Tinted when something is applied: a filtered list that looks
            // identical to an unfiltered one is how people conclude their
            // transactions have disappeared.
            color: filter.hasFilters ? context.colors.primary : null,
            background: filter.hasFilters ? finance.infoSurface : null,
            onPressed: () => TransactionFilterSheet.show(context),
          ),
          AppIconButton(
            icon: AppIcons.add,
            tooltip: 'Add transaction',
            onPressed: () => context.push(Routes.transactionNew),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  SearchField(
                    hint: 'Search description or category',
                    controller: _searchController,
                    onChanged: filterController.setQuery,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TypeChips(
                    selected: filter.type,
                    onSelected: filterController.toggleType,
                  ),
                  if (filter.hasFilters) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ActiveFilterBar(
                      count: filter.activeCount,
                      onClear: filterController.clearFilters,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: switch (listing) {
                AsyncData(:final value) => _Listing(
                  view: value,
                  filter: filter,
                  onClearSearch: () {
                    _searchController.clear();
                    filterController.clearQuery();
                  },
                  onClearFilters: filterController.clearFilters,
                ),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not load your transactions. $error',
                  onRetry: () => ref.invalidate(transactionListProvider),
                ),
                // Scrollable, because the placeholder stands in for a list
                // and has to behave like one. SkeletonList is a fixed
                // column of rows: dropped straight into this Expanded it
                // overflows a short phone by a few pixels while loading.
                _ => const SingleChildScrollView(child: SkeletonList()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelected});

  final TransactionType? selected;
  final ValueChanged<TransactionType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in TransactionType.values) ...[
          if (type != TransactionType.values.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _Chip(
              label: type.isIncome ? 'Income' : 'Expenses',
              icon: type.isIncome ? AppIcons.income : AppIcons.expense,
              isSelected: selected == type,
              onTap: () => onSelected(type),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final foreground = isSelected
        ? context.colors.onPrimary
        : finance.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? context.colors.primary : finance.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.sm, color: foreground),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A standing reminder that the list is narrowed, with one tap to undo it.
class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: finance.infoSurface,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        children: [
          Icon(AppIcons.filter, size: AppIconSize.sm, color: finance.infoText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'filter' : 'filters'} applied',
              style: AppTypography.caption.copyWith(color: finance.infoText),
            ),
          ),
          AppButton.text(
            label: 'Clear',
            size: AppButtonSize.small,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _Listing extends ConsumerWidget {
  const _Listing({
    required this.view,
    required this.filter,
    required this.onClearSearch,
    required this.onClearFilters,
  });

  final TransactionListView view;
  final TransactionFilter filter;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view.isAccountEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: EmptyState(
            icon: AppIcons.transactions,
            title: 'No transactions yet',
            message:
                'Record what you spend and earn, and your history builds '
                'up here.',
            actionLabel: 'Add your first one',
            onAction: () => context.push(Routes.transactionNew),
          ),
        ),
      );
    }

    if (!view.hasResults) {
      // A different fact from an empty account, and it needs a different
      // way out: the records exist, the question was just too narrow.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: AppIcons.search,
                title: 'Nothing matches',
                message:
                    'No transactions match what you are looking for. Try '
                    'different words, or widen the filters.',
              ),
              const SizedBox(height: AppSpacing.lg),
              // Stacked, not side by side. When both a search and filters
              // are narrowing the list — the case that most often produces
              // no results — two full labels do not fit a phone row.
              if (filter.hasQuery)
                AppButton.outlined(
                  label: 'Clear search',
                  onPressed: onClearSearch,
                ),
              if (filter.hasQuery && filter.hasFilters)
                const SizedBox(height: AppSpacing.sm),
              if (filter.hasFilters)
                AppButton.outlined(
                  label: 'Clear filters',
                  onPressed: onClearFilters,
                ),
            ],
          ),
        ),
      );
    }

    final today = ref.watch(clockProvider)();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      children: [
        TransactionsSummaryStrip(
          totals: view.totals,
          isFiltered: !filter.isEmpty,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final group in view.groups) ...[
          _GroupHeader(label: group.label),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final transaction in group.transactions) ...[
                  TransactionTile(
                    description: transaction.title,
                    // The label, not the id: the tile shows this string to
                    // the reader as well as using it for the icon, and
                    // `AppIcons.forCategory` lowercases before looking up,
                    // so "Food" resolves to the same icon as "food".
                    category: transaction.categoryLabel,
                    amount: transaction.amount,
                    date: DateLabels.rowLabel(transaction.date, today),
                    onTap: () =>
                        TransactionDetailSheet.show(context, transaction),
                  ),
                  if (transaction != group.transactions.last)
                    const AppDivider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          color: context.finance.textSecondary,
        ),
      ),
    );
  }
}
