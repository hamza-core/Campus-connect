import '../../../domain/models/chat_message.dart';
import '../chat_repository.dart';

/// Offline demo answers (no server): a few canned replies by keyword.
final class MockChatRepository implements ChatRepository {
  const MockChatRepository();

  static const _answers = {
    'deadline': 'Departments should respond within 24 hours for High priority, 72 hours for Medium and 7 days for Low. Later than that, the complaint is marked Overdue.',
    'photo': 'You can attach up to 3 photos. They are uploaded and attached to your complaint.',
    'rate': 'After a complaint is Resolved you can rate it once from 1 to 5 stars and add a comment.',
  };

  @override
  Future<ChatReply> ask(String message, List<ChatMessage> history) async {
    final text = message.toLowerCase();
    for (final entry in _answers.entries) {
      if (text.contains(entry.key)) {
        return ChatReply(
          answer: entry.value,
          sources: const [],
          mode: 'retrieval',
        );
      }
    }
    return const ChatReply(
      answer: 'This is the offline demo assistant. Ask about deadlines, photos or ratings.',
      sources: [],
      mode: 'retrieval',
    );
  }
}
