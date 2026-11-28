import 'chat_message.dart';

/// How many questions are left today.
///
/// A mock allowance, shown so the limit a paid tier will introduce is
/// visible in the design before anyone is charged for it. Nothing here
/// bills, enforces or expires — Phase 18 decides what the real numbers
/// are.
class AssistantUsage {
  const AssistantUsage({required this.used, required this.dailyLimit});

  final int used;
  final int dailyLimit;

  int get remaining {
    final left = dailyLimit - used;
    return left < 0 ? 0 : left;
  }

  bool get isExhausted => remaining == 0;

  /// 0..1 of the day's allowance spent.
  double get ratio => dailyLimit == 0 ? 0 : used / dailyLimit;

  String get label => '$remaining of $dailyLimit questions left today';

  AssistantUsage spendOne() =>
      AssistantUsage(used: used + 1, dailyLimit: dailyLimit);
}

/// Where answers come from.
///
/// Phase 18 replaces the mock with a real assistant. The interface stays
/// the same shape on purpose: a question, the conversation so far, and a
/// reply made of words plus the figures behind them.
abstract interface class AssistantRepository {
  /// Answers [question] in the context of [history].
  ///
  /// Throws [AssistantUnavailable] when it cannot answer at all, which
  /// the screen shows as a failed question with a Retry beside it.
  Future<AssistantReply> ask({
    required String question,
    List<ChatMessage> history = const [],
  });

  /// The day's allowance.
  Future<AssistantUsage> usage();
}

/// The assistant could not answer.
///
/// Carries a sentence written for the user: the screen shows [message]
/// as it is, so it never says "error 500" to someone who asked how much
/// they spent on food.
class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
