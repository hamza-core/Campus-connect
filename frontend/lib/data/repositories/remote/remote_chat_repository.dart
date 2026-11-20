import '../../../core/network/api_client.dart';
import '../../../domain/models/chat_message.dart';
import '../chat_repository.dart';

final class RemoteChatRepository implements ChatRepository {
  const RemoteChatRepository(this._api);
  final ApiClient _api;

  @override
  Future<ChatReply> ask(String message, List<ChatMessage> history) async {
    final response = await _api.request(
      'POST',
      'chat',
      body: {
        'message': message,
        'history': [
          for (final turn in history.where((m) => !m.failed))
            {'role': turn.role.name, 'text': turn.text},
        ],
      },
    );
    return ChatReply.fromJson(response['data']! as Map<String, Object?>);
  }
}
