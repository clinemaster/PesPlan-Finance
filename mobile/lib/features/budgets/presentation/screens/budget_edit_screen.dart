import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../providers/budget_providers.dart';
import 'budget_form_screen.dart';

/// Loads a budget by id, then hands it to the form.
///
/// Separate from the form so the form stays synchronous and takes a plain
/// [Budget]. That keeps it testable without a repository, and keeps "what
/// if it is gone" — a real case, since the detail sheet offers Delete
/// right beside Edit — out of the form's state handling.
class BudgetEditScreen extends ConsumerWidget {
  const BudgetEditScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetByIdProvider(id));

    return switch (budget) {
      AsyncData(:final value) when value != null => BudgetFormScreen(
        existing: value,
      ),
      AsyncData() => Scaffold(
        appBar: AppTopBar(
          title: 'Edit budget',
          showBack: true,
          onBack: () => context.pop(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Center(
            child: EmptyState(
              icon: AppIcons.error,
              title: 'That budget is gone',
              message:
                  'It may have been deleted. Go back to see your current '
                  'budgets.',
              actionLabel: 'Back to budgets',
              onAction: () => context.pop(),
            ),
          ),
        ),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppTopBar(
          title: 'Edit budget',
          showBack: true,
          onBack: () => context.pop(),
        ),
        body: ErrorState(
          message: 'We could not open that budget. $error',
          onRetry: () => ref.invalidate(budgetByIdProvider(id)),
        ),
      ),
      _ => const Scaffold(
        appBar: AppTopBar(title: 'Edit budget', showBack: true),
        body: LoadingState(message: 'Opening budget'),
      ),
    };
  }
}
