import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/repositories/chat_repository.dart';
import 'package:project/domain/models/chat_message.dart';
import 'package:project/features/assistant/controllers/chat_controller.dart';

final class _Fake implements ChatRepository {
  _Fake({this.fail = false});
  final bool fail;
  List<ChatMessage>? seenHistory;

  @override
  Future<ChatReply> ask(String message, List<ChatMessage> history) async {
    seenHistory = history;
    if (fail) throw Exception('boom');
    return const ChatReply(
      answer: 'Hello',
      sources: [ChatSource(title: 'Deadlines', snippet: 's')],
      mode: 'ai',
    );
  }
}

void main() {
  test('sends a message and appends the reply with sources', () async {
    final repo = _Fake();
    final controller = ChatController(repo);
    await controller.send('  deadlines? ');
    expect(controller.messages.map((m) => m.role), [
      ChatRole.user,
      ChatRole.assistant,
    ]);
    expect(controller.messages.first.text, 'deadlines?');
    expect(controller.messages.last.sources.single.title, 'Deadlines');
    expect(repo.seenHistory, isEmpty);
    expect(controller.sending, isFalse);
  });

  test('ignores blank and overlong input', () async {
    final controller = ChatController(_Fake());
    await controller.send('   ');
    await controller.send('x' * 1001);
    expect(controller.messages, isEmpty);
  });

  test('shows a friendly failure message', () async {
    final controller = ChatController(_Fake(fail: true));
    await controller.send('hi');
    expect(controller.messages.last.failed, isTrue);
    expect(controller.sending, isFalse);
  });

  test('parses the API reply', () {
    final reply = ChatReply.fromJson({
      'answer': 'a',
      'mode': 'retrieval',
      'sources': [
        {'title': 't', 'snippet': 's'},
      ],
    });
    expect(reply.mode, 'retrieval');
    expect(reply.sources.single.snippet, 's');
  });
}
