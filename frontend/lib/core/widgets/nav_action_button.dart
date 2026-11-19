import 'package:flutter/material.dart';

/// Circular action button for the floating nav. Shows "+" and rotates 45°
/// into an "X" while [isClosing] is true. Scales down slightly while pressed.
final class NavActionButton extends StatefulWidget {
  const NavActionButton({
    super.key,
    required this.onPressed,
    this.isClosing = false,
    this.semanticLabel = 'Report an issue',
    this.closeSemanticLabel = 'Close',
  });

  static const double size = 64;

  final VoidCallback onPressed;
  final bool isClosing;
  final String semanticLabel;
  final String closeSemanticLabel;

  @override
  State<NavActionButton> createState() => _NavActionButtonState();
}

final class _NavActionButtonState extends State<NavActionButton> {
  static const _green = Color(0xFF004741);
  static const _cream = Color(0xFFF0EDE4);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 300);
    return Semantics(
      button: true,
      label: widget.isClosing
          ? widget.closeSemanticLabel
          : widget.semanticLabel,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed && !reduce ? .92 : 1,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green,
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: .30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkResponse(
                containedInkWell: true,
                highlightShape: BoxShape.circle,
                onTap: widget.onPressed,
                child: SizedBox.square(
                  dimension: NavActionButton.size,
                  child: Center(
                    child: AnimatedRotation(
                      turns: widget.isClosing ? .125 : 0,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: _cream,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
