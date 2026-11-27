import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../providers/savings_providers.dart';
import 'goal_form_screen.dart';

/// Loads a goal by id, then hands it to the form.
///
/// Separate from the form so the form stays synchronous and takes a plain
/// [SavingsGoal]. That keeps it testable without a repository, and keeps
/// "what if it is gone" — a real case, since Delete sits beside Edit on
/// the detail screen — out of the form's state handling.
class GoalEditScreen extends ConsumerWidget {
  const GoalEditScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalByIdProvider(id));

    return switch (goal) {
      AsyncData(:final value) when value != null => GoalFormScreen(
        existing: value,
      ),
      AsyncData() => Scaffold(
        appBar: AppTopBar(
          title: 'Edit goal',
          showBack: true,
          onBack: () => context.pop(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Center(
            child: EmptyState(
              icon: AppIcons.error,
              title: 'That goal is gone',
              message:
                  'It may have been deleted. Go back to see your current '
                  'goals.',
              actionLabel: 'Back to goals',
              onAction: () => context.pop(),
            ),
          ),
        ),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppTopBar(
          title: 'Edit goal',
          showBack: true,
          onBack: () => context.pop(),
        ),
        body: ErrorState(
          message: 'We could not open that goal. $error',
          onRetry: () => ref.invalidate(goalByIdProvider(id)),
        ),
      ),
      _ => const Scaffold(
        appBar: AppTopBar(title: 'Edit goal', showBack: true),
        body: LoadingState(message: 'Opening goal'),
      ),
    };
  }
}
