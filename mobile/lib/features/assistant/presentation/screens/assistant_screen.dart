import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/time/clock.dart';
import '../../domain/suggested_question.dart';
import '../providers/assistant_providers.dart';
import '../widgets/assistant_widgets.dart';

/// Asking about your own money, in your own words.
///
/// ## What it is allowed to say
///
/// Every figure in an answer comes from the repositories the other
/// screens read, so the assistant and Reports cannot disagree. It
/// answers questions about recorded money and says plainly when it
/// cannot — it does not give investment or tax advice, and the screen
/// does not imply that it can.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String question) async {
    if (question.trim().isEmpty) return;

    _input.clear();
    FocusScope.of(context).unfocus();

    final asking = ref.read(assistantProvider.notifier).ask(question);
    _scrollToLatest();
    await asking;
    _scrollToLatest();
  }

  /// Keeps the newest message in view.
  ///
  /// After the frame, not during it: the message being scrolled to does
  /// not exist until the list has been rebuilt with it.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final usage = ref.watch(assistantUsageProvider);
    final today = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppTopBar(
        title: 'Assistant',
        actions: [
          usage.maybeWhen(
            data: (value) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(child: UsageBadge(usage: value)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          AppIconButton(
            icon: AppIcons.add,
            tooltip: 'New conversation',
            onPressed: state.isEmpty
                ? null
                : () {
                    ref.read(assistantProvider.notifier).startNew();
                    _input.clear();
                  },
          ),
          AppIconButton(
            icon: AppIcons.transactions,
            tooltip: 'Conversation history',
            onPressed: () => context.push(Routes.assistantHistory),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.isEmpty
                  ? _Welcome(onAsk: _send)
                  : _Thread(scroll: _scroll, today: today, onAsk: _send),
            ),
            _Composer(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

/// Before anything has been asked.
class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xl,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      children: [
        const Center(child: AssistantAvatar(size: 64)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "Hi! I'm your LifePilot assistant.",
          textAlign: TextAlign.center,
          style: AppTypography.titleScreen.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'I can help you understand your spending, follow your budgets and '
          'see how your savings are going — all from what you record here.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: finance.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text(
          'Try asking',
          style: AppTypography.label.copyWith(color: finance.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final question in SuggestionGroup.opening)
              SuggestionChip(question: question, onTap: () => onAsk(question)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // The quick picks above are drawn from these groups, so the
        // groups skip what is already offered — the same chip twice on
        // one screen reads as a mistake.
        for (final group in SuggestionGroup.all) ...[
          if (group.remaining.isNotEmpty) ...[
            Text(
              group.title,
              style: AppTypography.label.copyWith(color: finance.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final question in group.remaining)
                  SuggestionChip(
                    question: question,
                    onTap: () => onAsk(question),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],

        const _PrivacyNote(),
      ],
    );
  }
}

/// The conversation so far.
class _Thread extends ConsumerWidget {
  const _Thread({
    required this.scroll,
    required this.today,
    required this.onAsk,
  });

  final ScrollController scroll;
  final DateTime today;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final state = ref.watch(assistantProvider);
    final controller = ref.read(assistantProvider.notifier);
    final messages = state.messages;

    final followUps = messages.isEmpty || messages.last.isUser
        ? const <String>[]
        : messages.last.followUps;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      children: [
        for (final message in messages)
          ChatBubble(
            message: message,
            today: today,
            onRetry: message.status.isFailed
                ? () => controller.retry(message.id)
                : null,
          ),

        if (state.isThinking) const TypingIndicator(),

        if (state.error != null && !state.isThinking) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: finance.expenseSurface,
              borderRadius: AppRadius.cardAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.error,
                  size: AppIconSize.sm,
                  color: finance.expenseText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    state.error!,
                    style: AppTypography.caption.copyWith(
                      color: finance.expenseText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (followUps.isNotEmpty && !state.isThinking) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final question in followUps)
                SuggestionChip(
                  question: question,
                  onTap: () => onAsk(question),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const _PrivacyNote(),
      ],
    );
  }
}

/// Where the question is typed.
class _Composer extends ConsumerWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final isThinking = ref.watch(assistantProvider).isThinking;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: finance.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              style: AppTypography.bodyMedium.copyWith(
                color: finance.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ask about your money',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Disabled while an answer is on its way: two questions in
          // flight would land in either order, and the second would read
          // as an answer to the first.
          AppIconButton(
            icon: AppIcons.forward,
            tooltip: 'Send',
            color: context.colors.onPrimary,
            background: isThinking
                ? finance.textDisabled
                : context.colors.primary,
            onPressed: isThinking ? null : () => onSend(controller.text),
          ),
        ],
      ),
    );
  }
}

/// What the assistant can see, said once and kept short.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.insurance,
          size: AppIconSize.sm,
          color: finance.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Answers come from what you record in LifePilot, and nothing '
            'leaves your phone. This is general guidance, not financial '
            'advice.',
            style: AppTypography.caption.copyWith(color: finance.textTertiary),
          ),
        ),
      ],
    );
  }
}
