import 'assistant_insight.dart';

/// Who said it.
enum MessageAuthor {
  user,
  assistant;

  bool get isUser => this == MessageAuthor.user;
}

/// Where a message is in its life.
///
/// Only the user's messages are ever [failed]: an answer that did not
/// arrive is a failure of the question that asked for it, and showing it
/// that way is what lets Retry live next to the thing to retry.
enum MessageStatus {
  sending,
  sent,
  failed;

  bool get isFailed => this == MessageStatus.failed;
}

/// One line of the conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.insights = const [],
    this.followUps = const [],
  });

  final String id;
  final MessageAuthor author;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;

  /// Cards attached to an answer. Always empty on a question.
  final List<AssistantInsight> insights;

  /// What the assistant suggests asking next. Empty on a question, and
  /// on an answer that has nothing obvious to follow.
  final List<String> followUps;

  bool get isUser => author.isUser;

  bool get hasInsights => insights.isNotEmpty;

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
    id: id,
    author: author,
    text: text,
    sentAt: sentAt,
    status: status ?? this.status,
    insights: insights,
    followUps: followUps,
  );
}

/// What the assistant sends back.
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.insights = const [],
    this.followUps = const [],
  });

  final String text;
  final List<AssistantInsight> insights;
  final List<String> followUps;
}
