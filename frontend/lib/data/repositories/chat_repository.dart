import '../../domain/models/chat_message.dart';

abstract interface class ChatRepository {
  Future<ChatReply> ask(String message, List<ChatMessage> history);
}
