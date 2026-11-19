import 'package:flutter/material.dart';

import '../theme/clay_style.dart';
import 'app_button.dart';

final class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

final class _ClayButtonState extends State<ClayButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.busy && widget.onPressed != null;
    final motion = !MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: enabled && motion ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && enabled && motion ? .97 : 1,
        duration: motion ? const Duration(milliseconds: 150) : Duration.zero,
        child: DecoratedBox(
          decoration: ClayStyle.decoration(Colors.transparent),
          child: AppButton(
            label: widget.label,
            onPressed: widget.onPressed,
            busy: widget.busy,
          ),
        ),
      ),
    );
  }
}
