import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/models/chat_message.dart';

final class ChatController extends ChangeNotifier {
  ChatController(this._repository);
  final ChatRepository _repository;

  final List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _disposed = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > 1000 || _sending) return;
    final history = List<ChatMessage>.of(_messages);
    _messages.add(ChatMessage(role: ChatRole.user, text: text));
    _sending = true;
    notifyListeners();
    try {
      final reply = await _repository.ask(text, history);
      _messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: reply.answer,
          sources: reply.sources,
        ),
      );
    } on AppException catch (error) {
      _messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: error.message,
          failed: true,
        ),
      );
    } catch (_) {
      _messages.add(
        const ChatMessage(
          role: ChatRole.assistant,
          text: 'The assistant is unavailable right now. Try again shortly.',
          failed: true,
        ),
      );
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
