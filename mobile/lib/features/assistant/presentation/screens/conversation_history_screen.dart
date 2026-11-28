import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/time/clock.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/conversation.dart';
import '../providers/assistant_providers.dart';

/// Everything asked before.
///
/// A separate screen rather than a drawer: a conversation list is a list
/// of things the user wanted to know, and it deserves the width to say
/// what each one was about.
class ConversationHistoryScreen extends ConsumerWidget {
  const ConversationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistantProvider);
    final today = ref.watch(clockProvider)();

    // The open conversation is listed too: coming here to re-read what
    // was just said and not finding it would be baffling.
    final conversations = [
      for (final conversation in state.conversations)
        if (!conversation.isEmpty) conversation,
    ]..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return Scaffold(
      appBar: AppTopBar(
        title: 'Conversations',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: conversations.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                itemCount: conversations.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];

                  return _ConversationTile(
                    conversation: conversation,
                    today: today,
                    isOpen: conversation.id == state.activeId,
                    onOpen: () {
                      ref
                          .read(assistantProvider.notifier)
                          .open(conversation.id);
                      context.pop();
                    },
                    onDelete: () => _confirmDelete(context, ref, conversation),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this conversation?',
      message:
          '"${conversation.title}" and its '
          '${conversation.messages.length} messages will be removed. Your '
          'transactions, budgets and goals are not affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed != true) return;

    await ref.read(assistantProvider.notifier).delete(conversation.id);

    if (!context.mounted) return;
    AppSnackbar.success(context, 'Conversation deleted');
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.today,
    required this.isOpen,
    required this.onOpen,
    required this.onDelete,
  });

  final Conversation conversation;
  final DateTime today;
  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  conversation.title.isEmpty
                      ? 'Conversation'
                      : conversation.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleCard.copyWith(
                    color: finance.textPrimary,
                  ),
                ),
              ),
              if (isOpen) ...[
                const SizedBox(width: AppSpacing.sm),
                const AppBadge(label: 'Open', tone: BadgeTone.primary),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            conversation.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: finance.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${conversation.questionCount} '
                  '${conversation.questionCount == 1 ? 'question' : 'questions'}'
                  ' · ${DateLabels.timeLabel(conversation.lastActivity, today)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: finance.textTertiary,
                  ),
                ),
              ),
              AppIconButton(
                icon: AppIcons.delete,
                tooltip: 'Delete conversation',
                color: finance.expenseText,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.screenH),
              child: EmptyState(
                icon: AppIcons.assistant,
                title: 'No conversations yet',
                message:
                    'Ask the assistant something and it will be kept here, '
                    'so you can pick the thread back up later.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
