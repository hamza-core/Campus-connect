import 'package:flutter/material.dart';

import '../theme/clay_style.dart';
import 'app_button.dart';

final class ClayButton extends StatelessWidget {
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ClayStyle.decoration(Colors.transparent),
    child: AppButton(label: label, onPressed: onPressed, busy: busy),
  );
}
