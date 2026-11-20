import 'package:flutter/material.dart';

/// Meaning of a button, so colour carries consistent meaning across the app:
/// brand green = default, green = completes something, blue = starts work,
/// red = destructive, outlined = secondary.
enum AppButtonTone { primary, success, info, destructive, neutral }

final class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tone = AppButtonTone.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final AppButtonTone tone;
  final IconData? icon;

  static const _border = Color(0xFFCFC9B8);

  Color? get _fill => switch (tone) {
    AppButtonTone.primary => null,
    AppButtonTone.success => const Color(0xFF15803D),
    AppButtonTone.info => const Color(0xFF1D4ED8),
    AppButtonTone.destructive => const Color(0xFFB91C1C),
    AppButtonTone.neutral => null,
  };

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final child = busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: label,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label)),
            ],
          );
    if (tone == AppButtonTone.neutral) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          side: const BorderSide(color: _border, width: 1.5),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        backgroundColor: _fill,
        foregroundColor: _fill == null ? null : Colors.white,
      ),
      child: child,
    );
  }
}
