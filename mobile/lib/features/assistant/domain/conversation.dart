import 'chat_message.dart';

/// One thread of questions and answers.
class Conversation {
  const Conversation({
    required this.id,
    required this.startedAt,
    required this.messages,
    this.title = '',
  });

  final String id;
  final DateTime startedAt;
  final List<ChatMessage> messages;

  /// Set from the first question asked, so the history list reads as a
  /// list of things the user wanted to know rather than "Conversation 3".
  final String title;

  bool get isEmpty => messages.isEmpty;

  /// What the history list shows under the title.
  String get preview {
    for (final message in messages.reversed) {
      if (!message.isUser && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return messages.isEmpty ? 'Nothing asked yet' : messages.last.text;
  }

  DateTime get lastActivity =>
      messages.isEmpty ? startedAt : messages.last.sentAt;

  int get questionCount => messages.where((m) => m.isUser).length;

  Conversation copyWith({List<ChatMessage>? messages, String? title}) =>
      Conversation(
        id: id,
        startedAt: startedAt,
        messages: messages ?? this.messages,
        title: title ?? this.title,
      );

  /// A title from the first question, trimmed to something a list row can
  /// hold.
  static String titleFrom(String question) {
    final text = question.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 48) return text;
    return '${text.substring(0, 45)}…';
  }

  @override
  bool operator ==(Object other) => other is Conversation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
