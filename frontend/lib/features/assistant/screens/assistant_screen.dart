import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../../../domain/models/chat_message.dart';
import '../controllers/chat_controller.dart';

final class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

final class _AssistantScreenState extends State<AssistantScreen> {
  static const _suggestions = [
    'How does CampusConnect work?',
    'How long until a complaint gets a response?',
    'What do the statuses mean?',
    'What is the status of my latest complaint?',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ChatController(AppScope.of(context).chat)
      ..addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty) return;
    _input.clear();
    _controller!.send(value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Campus assistant'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) => Column(
              children: [
                Expanded(child: _messages(controller)),
                _composer(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messages(ChatController controller) {
    if (controller.messages.isEmpty) {
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          const _Bubble(
            message: ChatMessage(
              role: ChatRole.assistant,
              text: 'Hi! I can explain how CampusConnect works and answer questions about your own complaints or work. What would you like to know?',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                ActionChip(label: Text(s), onPressed: () => _send(s)),
            ],
          ),
        ],
      );
    }
    final items = controller.messages;
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (controller.sending ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => index == items.length
          ? const _Typing()
          : _Bubble(message: items[index]),
    );
  }

  Widget _composer(ChatController controller) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.send,
            onSubmitted: controller.sending ? null : (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'Ask about CampusConnect…',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send',
          onPressed: controller.sending ? null : _send,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    ),
  );
}

final class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == ChatRole.user;
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine
                ? AppColors.primary
                : message.failed
                ? const Color(0xFFFBE9E7)
                : AppColors.surface,
            border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mine ? Colors.white : AppColors.text,
                    height: 1.35,
                  ),
                ),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sources: ${message.sources.map((s) => s.title).toSet().join(' · ')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(8),
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
