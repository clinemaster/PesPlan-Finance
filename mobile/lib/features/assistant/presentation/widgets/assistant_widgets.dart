import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../transactions/domain/date_labels.dart';
import '../../domain/assistant_insight.dart';
import '../../domain/assistant_repository.dart';
import '../../domain/chat_message.dart';

/// One message, from either side.
///
/// ## The two sides are told apart by shape, not only colour
///
/// The user's questions sit right, tinted and tight; answers sit left on
/// a card with a flat corner against the avatar. Someone who cannot
/// separate the two hues still reads the conversation correctly.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    required this.today,
    super.key,
    this.onRetry,
  });

  final ChatMessage message;
  final DateTime today;

  /// Shown on a failed question, and nowhere else.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final colors = context.colors;
    final isUser = message.isUser;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isUser ? colors.primary : colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.card),
          topRight: const Radius.circular(AppRadius.card),
          bottomLeft: Radius.circular(isUser ? AppRadius.card : AppRadius.xs),
          bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.card),
        ),
        border: isUser ? null : Border.all(color: finance.border),
      ),
      child: Text(
        message.text,
        style: AppTypography.bodyMedium.copyWith(
          color: isUser ? colors.onPrimary : finance.textPrimary,
          height: 1.45,
        ),
      ),
    );

    return Semantics(
      label: '${isUser ? 'You asked' : 'Assistant answered'}: ${message.text}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  const AssistantAvatar(),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: bubble),
              ],
            ),

            // The cards hang under the answer, full width: a bar chart
            // squeezed into a chat bubble is a bar chart nobody can read.
            if (message.hasInsights) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final insight in message.insights) ...[
                InsightCard(insight: insight),
                if (insight != message.insights.last)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],

            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : AppIconSize.xl + AppSpacing.sm,
              ),
              child: Text(
                message.status.isFailed
                    ? 'Not sent'
                    : DateLabels.timeLabel(message.sentAt, today),
                style: AppTypography.caption.copyWith(
                  color: message.status.isFailed
                      ? finance.expenseText
                      : finance.textTertiary,
                ),
              ),
            ),

            if (message.status.isFailed && onRetry != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton.text(
                label: 'Try again',
                icon: AppIcons.refresh,
                size: AppButtonSize.small,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The assistant's mark. Small, and the same everywhere it appears.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = AppIconSize.xl});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.assistant,
        size: size / 2,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}

/// A figure, a bar, or a short list — attached to an answer.
class InsightCard extends StatelessWidget {
  const InsightCard({required this.insight, super.key});

  final AssistantInsight insight;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final accent = switch (insight.tone) {
      InsightTone.good => finance.income,
      InsightTone.watch => context.colors.primary,
      InsightTone.warning => finance.expense,
      InsightTone.neutral => finance.textSecondary,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: AppTypography.label.copyWith(color: finance.textSecondary),
          ),
          if (insight.amount != null) ...[
            const SizedBox(height: AppSpacing.xs),
            MoneyText(
              insight.amount!,
              size: MoneySize.large,
              colorBySign: false,
              color: finance.textPrimary,
            ),
          ],
          if (insight.caption != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              insight.caption!,
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
          if (insight.ratio != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(
              value: insight.ratio!,
              color: accent,
              semanticLabel: insight.title,
            ),
          ],
          if (insight.hasRows) ...[
            const SizedBox(height: AppSpacing.md),
            for (final row in insight.rows) ...[
              _InsightRowView(row: row, accent: accent),
              if (row != insight.rows.last)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _InsightRowView extends StatelessWidget {
  const _InsightRowView({required this.row, required this.accent});

  final InsightRow row;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: finance.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              row.value,
              style: AppTypography.label.copyWith(color: finance.textPrimary),
            ),
          ],
        ),
        if (row.share != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppProgressBar(
            value: row.share!,
            color: accent,
            height: AppSpacing.xs,
            semanticLabel: row.label,
          ),
        ],
      ],
    );
  }
}

/// Three dots, while an answer is being worked out.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Still under reduced motion: the indicator's job is to say "working
    // on it", and the words beside it already do that.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion && !_wave.isAnimating) _wave.repeat();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      liveRegion: true,
      label: 'Thinking',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            const AssistantAvatar(),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card),
                  topRight: Radius.circular(AppRadius.card),
                  bottomLeft: Radius.circular(AppRadius.xs),
                  bottomRight: Radius.circular(AppRadius.card),
                ),
                border: Border.all(color: finance.border),
              ),
              child: AnimatedBuilder(
                animation: _wave,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Opacity(
                        opacity: _opacityFor(i),
                        child: Container(
                          width: AppSpacing.xs,
                          height: AppSpacing.xs,
                          decoration: BoxDecoration(
                            color: finance.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Thinking…',
              style: AppTypography.caption.copyWith(
                color: finance.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _opacityFor(int index) {
    final offset = (_wave.value + index / 3) % 1;
    return 0.35 + (offset < 0.5 ? offset : 1 - offset);
  }
}

/// A question the user can send with one tap.
class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    required this.question,
    required this.onTap,
    super.key,
  });

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      button: true,
      label: question,
      excludeSemantics: true,
      child: Material(
        color: finance.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                question,
                style: AppTypography.bodySmall.copyWith(
                  color: finance.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What is left of today's mock allowance.
class UsageBadge extends StatelessWidget {
  const UsageBadge({required this.usage, super.key});

  final AssistantUsage usage;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: '${usage.remaining}/${usage.dailyLimit}',
      icon: AppIcons.assistant,
      tone: usage.isExhausted ? BadgeTone.warning : BadgeTone.neutral,
    );
  }
}
