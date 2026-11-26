import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../providers/transaction_providers.dart';
import 'transaction_form_screen.dart';

/// Loads a transaction by id, then hands it to the form.
///
/// A separate screen from the form so the form can stay synchronous and
/// take a plain [Transaction]. That keeps the form testable without a
/// repository, and keeps "what if it is gone" — a real case, since the
/// detail sheet offers Delete right next to Edit — out of the form's
/// state handling.
class TransactionEditScreen extends ConsumerWidget {
  const TransactionEditScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionByIdProvider(id));

    return switch (transaction) {
      AsyncData(:final value) when value != null => TransactionFormScreen(
        existing: value,
      ),
      AsyncData() => _Missing(onBack: () => context.pop()),
      AsyncError(:final error) => Scaffold(
        appBar: AppTopBar(
          title: 'Edit transaction',
          showBack: true,
          onBack: () => context.pop(),
        ),
        body: ErrorState(
          message: 'We could not open that transaction. $error',
          onRetry: () => ref.invalidate(transactionByIdProvider(id)),
        ),
      ),
      _ => const Scaffold(
        appBar: AppTopBar(title: 'Edit transaction', showBack: true),
        body: LoadingState(message: 'Opening transaction'),
      ),
    };
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Edit transaction',
        showBack: true,
        onBack: onBack,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Center(
          child: EmptyState(
            icon: AppIcons.error,
            title: 'That transaction is gone',
            message:
                'It may have been deleted. Go back to see your current '
                'history.',
            actionLabel: 'Back to transactions',
            onAction: onBack,
          ),
        ),
      ),
    );
  }
}
