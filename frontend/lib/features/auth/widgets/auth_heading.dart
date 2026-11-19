import 'package:flutter/material.dart';

import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/illustration_image.dart';

final class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.registration});
  final bool registration;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return HeroHeader(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              registration ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: palette.onPrimary,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const CircleBadge(
            size: 104,
            child: IllustrationImage(filename: 'login-signup.jpg', size: 104),
          ),
        ],
      ),
    );
  }
}

/// Pill toggle between Log in and Sign up.
final class AuthToggle extends StatelessWidget {
  const AuthToggle({
    super.key,
    required this.registration,
    required this.onChanged,
  });
  final bool registration;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget tab(String label, bool value) {
      final selected = registration == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => onChanged(value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : const Color(0xFF5F6B68),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3ECE9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [tab('Log in', false), tab('Sign up', true)]),
    );
  }
}
