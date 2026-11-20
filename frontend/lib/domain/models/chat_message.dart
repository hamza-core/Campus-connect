enum ChatRole { user, assistant }

final class ChatSource {
  const ChatSource({required this.title, required this.snippet});
  factory ChatSource.fromJson(Map<String, Object?> json) => ChatSource(
    title: json['title'] as String? ?? '',
    snippet: json['snippet'] as String? ?? '',
  );
  final String title;
  final String snippet;
}

final class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.failed = false,
  });
  final ChatRole role;
  final String text;
  final List<ChatSource> sources;
  final bool failed;
}

final class ChatReply {
  const ChatReply({
    required this.answer,
    required this.sources,
    required this.mode,
  });
  factory ChatReply.fromJson(Map<String, Object?> json) => ChatReply(
    answer: json['answer'] as String? ?? '',
    sources: List.unmodifiable(
      ((json['sources'] as List?) ?? const []).cast<Map<String, Object?>>().map(
        ChatSource.fromJson,
      ),
    ),
    mode: json['mode'] as String? ?? 'retrieval',
  );
  final String answer;
  final List<ChatSource> sources;

  /// `ai` when a language model answered, `retrieval` for the keyword fallback.
  final String mode;
}
