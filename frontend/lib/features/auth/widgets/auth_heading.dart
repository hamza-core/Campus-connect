import 'package:flutter/material.dart';

import '../../../core/widgets/illustration_image.dart';

final class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.registration});
  final bool registration;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                registration ? 'Create your account' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: palette.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const IllustrationImage(filename: 'login-signup.jpg', size: 72),
          ],
        ),
      ),
    );
  }
}
