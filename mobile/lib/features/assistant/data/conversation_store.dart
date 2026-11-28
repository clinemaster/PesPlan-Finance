import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

/// Keeps conversations between launches.
///
/// ## Words, not figures
///
/// Only the text of each message is stored — never the insight cards.
/// The cards are derived from the user's current figures, and a card
/// saved in October would still be claiming October's budget in
/// December. A re-opened conversation shows what was said; asking again
/// is what gets today's numbers.
class ConversationStore {
  const ConversationStore(this._store);

  final KeyValueStore _store;

  static const String _key = 'assistant.conversations';

  /// The most that is kept. A chat history is a convenience, not an
  /// archive, and an unbounded list of every question ever asked is a
  /// file that only grows.
  static const int maxConversations = 20;

  bool get hasStoredData => _store.getString(_key) != null;

  List<Conversation> read() {
    final raw = _store.getString(_key);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [for (final entry in list) _decode(entry as Map<String, dynamic>)];
    } on Object {
      // Unreadable state is treated as none: losing a chat history is
      // recoverable, and a crash on launch is not.
      return [];
    }
  }

  Future<void> write(List<Conversation> conversations) {
    final kept = conversations.take(maxConversations).toList();
    return _store.setString(
      _key,
      jsonEncode([for (final conversation in kept) _encode(conversation)]),
    );
  }

  Future<void> clear() => _store.remove(_key);

  static Map<String, dynamic> _encode(Conversation conversation) => {
    'id': conversation.id,
    'title': conversation.title,
    'startedAt': conversation.startedAt.toIso8601String(),
    'messages': [
      for (final message in conversation.messages)
        {
          'id': message.id,
          'author': message.author.name,
          'text': message.text,
          'sentAt': message.sentAt.toIso8601String(),
        },
    ],
  };

  static Conversation _decode(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '',
    startedAt: DateTime.parse(json['startedAt'] as String),
    messages: [
      for (final entry in (json['messages'] as List<dynamic>))
        _decodeMessage(entry as Map<String, dynamic>),
    ],
  );

  static ChatMessage _decodeMessage(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    author: json['author'] == 'user'
        ? MessageAuthor.user
        : MessageAuthor.assistant,
    text: json['text'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String),
  );
}
