import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class ClayStyle {
  static BoxDecoration decoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: AppColors.text.withValues(alpha: .07),
        offset: const Offset(0, 8),
        blurRadius: 22,
      ),
    ],
  );
}
