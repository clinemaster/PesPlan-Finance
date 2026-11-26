import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/dashboard_data.dart';
import '../../domain/dashboard_period.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/budget_overview_section.dart';
import '../widgets/dashboard_empty.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/period_selector.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_transactions_section.dart';
import '../widgets/savings_overview_section.dart';
import '../widgets/summary_section.dart';
import '../widgets/trend_chart_section.dart';

/// The dashboard.
///
/// ## Reading order
///
/// The sections descend by how often the answer is needed: where do I
/// stand, what can I do about it, what happened, and then the two
/// commitments (budget, goals) that give the figures meaning. A user who
/// reads only the first screenful has the answer they opened the app for.
///
/// The header and period selector stay above the async boundary. They
/// depend on the profile and the user's own choice, not on the figures, so
/// reloading a period should not blank out the greeting or the control that
/// triggered the reload.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.xxxl,
            ),
            children: [
              const DashboardHeader(),
              const SizedBox(height: AppSpacing.xl),
              const PeriodSelector(),
              const SizedBox(height: AppSpacing.sectionGap),

              switch (dashboard) {
                AsyncData(:final value) when value.isEmpty =>
                  const DashboardEmpty(),
                AsyncData(:final value) => _Loaded(data: value, period: period),
                AsyncError(:final error) => ErrorState(
                  message: 'We could not load your overview. $error',
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
                _ => const _LoadingSkeleton(),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.data, required this.period});

  final DashboardData data;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummarySection(data: data, period: period),
        const SizedBox(height: AppSpacing.sectionGap),
        const QuickActions(),
        const SizedBox(height: AppSpacing.sectionGap),
        TrendChartSection(data: data, period: period),
        const SizedBox(height: AppSpacing.sectionGap),
        BudgetOverviewSection(budget: data.budget),
        const SizedBox(height: AppSpacing.sectionGap),
        SavingsOverviewSection(savings: data.savings),
        const SizedBox(height: AppSpacing.sectionGap),
        RecentTransactionsSection(transactions: data.recentTransactions),
      ],
    );
  }
}

/// Shapes rather than a spinner.
///
/// A centred spinner on a screen this tall tells the user nothing about
/// what is coming and makes the layout jump when it resolves. Blocks in the
/// shape of the real cards keep the page still.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Skeleton(height: 112, radius: AppRadius.card),
        SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(child: Skeleton(height: 96, radius: AppRadius.card)),
            SizedBox(width: AppSpacing.cardGap),
            Expanded(child: Skeleton(height: 96, radius: AppRadius.card)),
          ],
        ),
        SizedBox(height: AppSpacing.sectionGap),
        Skeleton(height: 240, radius: AppRadius.card),
        SizedBox(height: AppSpacing.sectionGap),
        Skeleton(height: 180, radius: AppRadius.card),
      ],
    );
  }
}
