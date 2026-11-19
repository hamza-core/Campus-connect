import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class ClayStyle {
  static BoxDecoration decoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
    boxShadow: kUseClay
        ? const [
            BoxShadow(
              color: AppColors.clayShadow,
              offset: Offset(8, 8),
              blurRadius: 20,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 16,
            ),
          ]
        : null,
  );
}
