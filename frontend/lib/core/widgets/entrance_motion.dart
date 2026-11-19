import 'package:flutter/material.dart';

final class EntranceMotion extends StatelessWidget {
  const EntranceMotion({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || index >= 15) return child;
    final delay = index.clamp(0, 7) * .04;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 9),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
