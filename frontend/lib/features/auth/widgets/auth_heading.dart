import 'package:flutter/material.dart';

import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/illustration_image.dart';

/// Hero for the login / sign-up screens. [compact] shrinks it while the
/// keyboard is open so the form stays visible and nothing collides with the
/// status bar.
final class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.registration,
    this.compact = false,
  });
  final bool registration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    return HeroHeader(
      padding: EdgeInsets.fromLTRB(
        24,
        compact ? 12 : 28,
        24,
        compact ? 56 : 64,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    registration ? 'Create your account' : 'Welcome back',
                    style:
                        (compact
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.displaySmall)
                            ?.copyWith(
                              color: palette.onPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 10),
                    Text(
                      registration
                          ? 'Join CampusConnect in a minute.'
                          : 'Sign in to track your complaints.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: palette.onPrimary.withValues(alpha: .85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!compact)
              const CircleBadge(
                size: 104,
                child: IllustrationImage(
                  filename: 'login-signup.jpg',
                  size: 104,
                ),
              ),
          ],
        ),
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
        border: Border.all(color: const Color(0xFFCFC9B8)),
      ),
      child: Row(children: [tab('Log in', false), tab('Sign up', true)]),
    );
  }
}

/// Live checklist for the password rules (8–72 chars, a letter and a number).
final class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final text = value.text;
          final rules = [
            ('8–72 characters', text.length >= 8 && text.length <= 72),
            ('Contains a letter', RegExp('[A-Za-z]').hasMatch(text)),
            ('Contains a number', RegExp('[0-9]').hasMatch(text)),
          ];
          return Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (label, ok) in rules)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: ok
                            ? const Color(0xFF15803D)
                            : const Color(0xFF8A938F),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ok
                                ? const Color(0xFF15803D)
                                : const Color(0xFF5F6B68),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
}
