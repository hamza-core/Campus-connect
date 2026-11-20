import 'package:flutter/material.dart';

/// Floating chat button shown over every signed-in screen.
final class ChatFab extends StatelessWidget {
  const ChatFab({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open chat assistant',
    excludeSemantics: true,
    child: Material(
      color: const Color(0xFF004741),
      elevation: 6,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFFF0EDE4), width: 2),
      ),
      child: InkResponse(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox.square(
          dimension: 56,
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFFF0EDE4),
            size: 26,
          ),
        ),
      ),
    ),
  );
}
