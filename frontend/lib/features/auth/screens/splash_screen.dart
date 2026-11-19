import 'package:flutter/material.dart';

final class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.primary,
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: .92 + value * .08, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 42,
              child: Text('CC', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 24),
            Text(
              'CampusConnect',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your voice, heard on campus',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ],
        ),
      ),
    ),
  );
}
