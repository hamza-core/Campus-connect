import 'package:flutter/material.dart';

/// Chat button for every signed-in screen. Drag it anywhere; when released it
/// snaps to the nearest left or right edge. A tap opens the chat.
final class DraggableChatFab extends StatefulWidget {
  const DraggableChatFab({super.key, required this.onPressed});
  final VoidCallback onPressed;

  static const double size = 56;

  @override
  State<DraggableChatFab> createState() => _DraggableChatFabState();
}

final class _DraggableChatFabState extends State<DraggableChatFab> {
  static const _margin = 12.0;
  // Position kept for the whole app session, not per screen.
  static Offset? _remembered;
  Offset? _offset;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final media = MediaQuery.of(context);
      final minX = _margin;
      final maxX = box.maxWidth - DraggableChatFab.size - _margin;
      final minY = media.padding.top + _margin;
      final maxY =
          box.maxHeight -
          DraggableChatFab.size -
          media.padding.bottom -
          _margin;
      final start = Offset(maxX, maxY - 84);
      final raw = _offset ?? _remembered ?? start;
      final position = Offset(
        raw.dx.clamp(minX, maxX),
        raw.dy.clamp(minY, maxY),
      );
      return Stack(
        children: [
          AnimatedPositioned(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: position.dx,
            top: position.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (details) => setState(() {
                _offset = Offset(
                  (position.dx + details.delta.dx).clamp(minX, maxX),
                  (position.dy + details.delta.dy).clamp(minY, maxY),
                );
              }),
              onPanEnd: (_) => setState(() {
                _dragging = false;
                final current = _offset ?? position;
                final snapped = Offset(
                  current.dx + DraggableChatFab.size / 2 < box.maxWidth / 2
                      ? minX
                      : maxX,
                  current.dy,
                );
                _offset = snapped;
                _remembered = snapped;
              }),
              onTap: widget.onPressed,
              child: Semantics(
                button: true,
                label: 'Open chat assistant. Drag to move.',
                excludeSemantics: true,
                child: const Material(
                  color: Color(0xFF004741),
                  elevation: 6,
                  shape: CircleBorder(
                    side: BorderSide(color: Color(0xFFF0EDE4), width: 2),
                  ),
                  child: SizedBox.square(
                    dimension: DraggableChatFab.size,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFFF0EDE4),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
