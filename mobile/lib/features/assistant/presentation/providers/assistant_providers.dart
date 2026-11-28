import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../../core/time/clock.dart';
import '../../../budgets/presentation/providers/budget_providers.dart';
import '../../../reports/presentation/providers/report_providers.dart';
import '../../../savings/presentation/providers/savings_providers.dart';
import '../../data/conversation_store.dart';
import '../../data/mock_assistant_repository.dart';
import '../../domain/assistant_repository.dart';
import '../../domain/chat_message.dart';
import '../../domain/conversation.dart';

/// Whether the assistant should fail on the next question.
///
/// A review control, like the empty dashboard: an error state nobody can
/// reach is an error state nobody has looked at.
class AssistantFailureSwitch extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool shouldFail}) => state = shouldFail;
}

final assistantShouldFailProvider =
    NotifierProvider<AssistantFailureSwitch, bool>(AssistantFailureSwitch.new);

/// Where answers come from.
///
/// Built on the repositories that own each figure, so what the assistant
/// says and what Reports, Budgets and Goals show are the same numbers.
/// Phase 18 overrides this with a real assistant.
final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => MockAssistantRepository(
    now: ref.watch(clockProvider),
    reports: ref.watch(reportRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    savings: ref.watch(savingsRepositoryProvider),
    shouldFail: ref.watch(assistantShouldFailProvider),
  ),
);

/// The day's mock allowance.
final assistantUsageProvider = FutureProvider<AssistantUsage>((ref) {
  // Rebuilt after every exchange, so the figure on screen is the one the
  // repository holds.
  ref.watch(assistantProvider);
  return ref.read(assistantRepositoryProvider).usage();
});

/// Every conversation, and which one is open.
class AssistantState {
  const AssistantState({
    required this.conversations,
    required this.activeId,
    this.isThinking = false,
    this.error,
  });

  final List<Conversation> conversations;

  /// The open conversation. Null before the first question of a new one
  /// is asked — a thread with nothing in it is not yet a conversation.
  final String? activeId;

  /// True while an answer is on its way.
  final bool isThinking;

  /// Why the last question failed, if it did. Lives in the state rather
  /// than on the controller so the retry row rebuilds with it.
  final String? error;

  Conversation? get active {
    for (final conversation in conversations) {
      if (conversation.id == activeId) return conversation;
    }
    return null;
  }

  List<ChatMessage> get messages => active?.messages ?? const [];

  bool get isEmpty => messages.isEmpty;

  /// History, newest first, excluding whatever is open.
  List<Conversation> get history {
    final rest = [
      for (final conversation in conversations)
        if (conversation.id != activeId && !conversation.isEmpty) conversation,
    ]..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return rest;
  }

  AssistantState copyWith({
    List<Conversation>? conversations,
    String? activeId,
    bool clearActive = false,
    bool? isThinking,
    String? error,
    bool clearError = false,
  }) => AssistantState(
    conversations: conversations ?? this.conversations,
    activeId: clearActive ? null : (activeId ?? this.activeId),
    isThinking: isThinking ?? this.isThinking,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The conversation, and what asking a question does to it.
class AssistantController extends Notifier<AssistantState> {
  late final ConversationStore _store;

  int _sequence = 0;

  @override
  AssistantState build() {
    _store = ConversationStore(ref.watch(keyValueStoreProvider));

    // Restored synchronously, like every other controller in this app:
    // the history is read before the first frame rather than appearing a
    // moment after it.
    final stored = _store.read();
    return AssistantState(conversations: stored, activeId: null);
  }

  AssistantRepository get _repository => ref.read(assistantRepositoryProvider);

  String _newId(String prefix) {
    _sequence++;
    final stamp = ref.read(clockProvider)().microsecondsSinceEpoch;
    return '$prefix-$stamp-$_sequence';
  }

  /// Puts the open conversation away and starts a fresh one.
  ///
  /// Nothing is created until the first question: an empty thread in the
  /// history list is a row that says nothing.
  void startNew() => state = state.copyWith(clearActive: true);

  void open(String id) => state = state.copyWith(activeId: id);

  Future<void> delete(String id) async {
    final remaining = [
      for (final conversation in state.conversations)
        if (conversation.id != id) conversation,
    ];

    state = AssistantState(
      conversations: remaining,
      activeId: state.activeId == id ? null : state.activeId,
    );
    await _store.write(remaining);
  }

  /// Asks a question and waits for the answer.
  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.isThinking) return;

    final now = ref.read(clockProvider)();
    final conversation = state.active ?? _begin(text, now);

    final asked = ChatMessage(
      id: _newId('q'),
      author: MessageAuthor.user,
      text: text,
      sentAt: now,
    );

    _replace(
      conversation.copyWith(messages: [...conversation.messages, asked]),
      isThinking: true,
    );

    try {
      final reply = await _repository.ask(
        question: text,
        history: state.messages,
      );

      _append(
        ChatMessage(
          id: _newId('a'),
          author: MessageAuthor.assistant,
          text: reply.text,
          sentAt: ref.read(clockProvider)(),
          insights: reply.insights,
          followUps: reply.followUps,
        ),
      );
    } on AssistantUnavailable catch (failure) {
      _markFailed(asked.id, failure.message);
    } catch (error) {
      _markFailed(asked.id, 'Something went wrong. Please try again.');
    }
  }

  /// Sends a failed question again.
  ///
  /// The failed message is removed first so the thread does not end up
  /// with the same question twice — the user asked once.
  Future<void> retry(String messageId) async {
    final conversation = state.active;
    if (conversation == null) return;

    final failed = conversation.messages
        .where((message) => message.id == messageId)
        .firstOrNull;
    if (failed == null) return;

    _replace(
      conversation.copyWith(
        messages: [
          for (final message in conversation.messages)
            if (message.id != messageId) message,
        ],
      ),
    );

    await ask(failed.text);
  }

  Conversation _begin(String question, DateTime now) {
    final conversation = Conversation(
      id: _newId('c'),
      startedAt: now,
      messages: const [],
      title: Conversation.titleFrom(question),
    );

    state = state.copyWith(
      conversations: [conversation, ...state.conversations],
      activeId: conversation.id,
    );
    return conversation;
  }

  void _append(ChatMessage message) {
    final conversation = state.active;
    if (conversation == null) return;

    _replace(
      conversation.copyWith(messages: [...conversation.messages, message]),
      isThinking: false,
    );
  }

  void _markFailed(String messageId, String reason) {
    final conversation = state.active;
    if (conversation == null) return;

    _replace(
      conversation.copyWith(
        messages: [
          for (final message in conversation.messages)
            if (message.id == messageId)
              message.copyWith(status: MessageStatus.failed)
            else
              message,
        ],
      ),
      isThinking: false,
      error: reason,
    );
  }

  /// The one place the state and the store are written.
  void _replace(Conversation conversation, {bool? isThinking, String? error}) {
    final conversations = [
      for (final existing in state.conversations)
        if (existing.id == conversation.id) conversation else existing,
    ];

    state = AssistantState(
      conversations: conversations,
      activeId: conversation.id,
      isThinking: isThinking ?? state.isThinking,
      error: error,
    );

    // Written on every change rather than on leaving: a chat the user
    // backs out of mid-answer is still a chat they had.
    _store.write(conversations);
  }
}

final assistantProvider = NotifierProvider<AssistantController, AssistantState>(
  AssistantController.new,
);
